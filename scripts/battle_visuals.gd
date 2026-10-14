extends Node3D

# Presentation follows host outcomes; animation never causes damage or deliveries.
var world: Node3D
var battles: Dictionary = {}
var villages: Dictionary = {}
var fallen: Array = []
var clock := 0.0
var arrows: Array = []
var fighters: Dictionary = {}
var observed_events: Dictionary = {}

func setup(scene: Node3D) -> void:
    world = scene

func clear() -> void:
    for child in get_children(): child.queue_free()
    battles.clear()
    villages.clear()
    fallen.clear()
    arrows.clear()
    fighters.clear()
    observed_events.clear()

func figure(unit: String, index: int, parent: Node3D) -> Dictionary:
    var p: Dictionary = world.citizens.make_person(index)
    p.node.reparent(parent)
    p.job = unit
    world.citizens.equip(p)
    return p

func refresh() -> void:
    var active: Dictionary = {}
    var origin := Vector2(world.sim.world_origin[0], world.sim.world_origin[1])
    var active_fighters: Dictionary = {}
    for info in world.session.visible_campaigns:
        if info.get("scene", {}).is_empty(): continue
        var point: Vector2 = world.world_entities.campaign_math.campaign_point(info) - origin if info.own else Vector2(info.point[0], info.point[1])
        if not world.sim.has_live_sight(point): continue
        var key := str(int(info.id))
        active[key] = true
        var scene: Dictionary = info.scene
        if not scene.get("tactical", {}).is_empty():
            refresh_tactical(info, scene.tactical, active_fighters)
            continue
        if not battles.has(key):
            battles[key] = {"figures": [], "signature": "", "losses": [int(scene.attacker_losses), int(scene.defender_losses)], "militia_losses": int(scene.militia_losses), "label": world.world_entities.caption(self)}
        var battle: Dictionary = battles[key]
        for side in range(2):
            var total: int = scene.attacker_losses if side == 0 else scene.defender_losses
            var new_losses := maxi(0, total - int(battle.losses[side]))
            for i in range(mini(12, new_losses)):
                var villager: bool = side == 1 and i < maxi(0, int(scene.militia_losses) - int(battle.militia_losses))
                var body := figure("Resting" if villager else "Militia", i, self)
                var spot := point + Vector2(-0.7 if side == 0 else 0.7, (i % 5 - 2) * 0.7)
                body.node.position = world.pos(spot.x, spot.y, 0.08)
                body.node.rotation.y = PI * 0.5 if side == 0 else -PI * 0.5
                fallen.append({"figure": body, "age": 0.0, "point": spot})
            battle.losses[side] = total
        battle.militia_losses = int(scene.militia_losses)
        var defenders: Array = scene.defenders if info.phase == "Fighting" else []
        var signature := str(defenders)
        if battle.signature != signature:
            for p in battle.figures: p.node.queue_free()
            battle.figures = []
            for i in range(defenders.size()):
                var p := figure(defenders[i].unit, i, self)
                p.villager = defenders[i].villager
                if p.villager:
                    # Civilians retain ordinary clothing and improvise spears.
                    p.node.scale *= 0.96
                battle.figures.append(p)
            battle.signature = signature
        battle.label.position = world.pos(point.x + 1.6, point.y, 3.0)
        battle.label.text = "Villagers defending" if defenders.any(func(p: Dictionary) -> bool: return p.villager) else "Settlement defenders"
        battle.label.visible = not defenders.is_empty()
        battle.point = point
        battle.info = info
    for key in battles.keys():
        if key not in active:
            for p in battles[key].figures: p.node.queue_free()
            battles[key].label.queue_free()
            battles.erase(key)
    for key in fighters.keys():
        if not active_fighters.has(key):
            fighters[key].figure.node.queue_free()
            fighters.erase(key)
    refresh_villages()

func refresh_tactical(info: Dictionary, tactical: Dictionary, active: Dictionary) -> void:
    var campaign_key := str(int(info.id))
    var baseline := not observed_events.has(campaign_key)
    var previous := int(observed_events.get(campaign_key, tactical.serial))
    for f in tactical.fighters:
        var key := "%s:%d:%d" % [campaign_key, f.side, f.id]
        active[key] = true
        if not fighters.has(key):
            var p := figure(f.unit if f.armed else "Resting", int(f.id), self)
            p.node.scale *= lerpf(0.45, 1.0, clampf(float(f.get("age", 16)) / 16.0, 0, 1))
            if f.armed and not f.civilian:
                world.inspectable(p.node, {"kind": "Army", "own": f.own, "campaign": int(info.id), "army": int(f.army)})
            p.node.position = world.pos(f.point[0], f.point[1], 0.04)
            fighters[key] = {"figure": p, "info": f}
        fighters[key].info = f
    for e in tactical.events:
        if baseline or int(e.serial) <= previous: continue
        var spot := Vector2(e.from[0], e.from[1])
        if e.kind == "Fall":
            var p := figure(e.unit if not e.civilian else "Resting", int(e.id), self)
            p.node.position = world.pos(spot.x, spot.y, 0.04)
            fallen.append({"figure": p, "age": 0.0, "point": spot})
        elif e.kind == "Arrow":
            var key := "%s:%d:%d" % [campaign_key, e.side, e.id]
            if fighters.has(key): projectile(fighters[key].figure, world.pos(e.to[0], e.to[1], 1.0), true)
    observed_events[campaign_key] = int(tactical.serial)

func refresh_villages() -> void:
    for key in villages.keys():
        if not world.sim.known_civilizations.has(key):
            for p in villages[key].figures: p.node.queue_free()
            villages.erase(key)
    for key in world.sim.known_civilizations:
        var info: Dictionary = world.sim.known_civilizations[key]
        var point := Vector2(info.point[0], info.point[1])
        var live: bool = world.sim.has_live_sight(point)
        if not villages.has(key): villages[key] = {"figures": [], "signature": ""}
        var village: Dictionary = villages[key]
        var inhabitants: Array = info.get("inhabitants", [])
        var shapes: Array = []
        for person in inhabitants: shapes.append([person.id, person.job])
        var signature := str(shapes)
        if live and village.signature != signature:
            for p in village.figures: p.node.queue_free()
            village.figures = []
            for i in range(inhabitants.size()):
                var p := figure(inhabitants[i].job, int(inhabitants[i].id), self)
                p.node.scale *= lerpf(0.45, 1.0, clampf(float(inhabitants[i].age) / 16.0, 0, 1))
                village.figures.append(p)
            village.signature = signature
        if live:
            for i in range(mini(village.figures.size(), inhabitants.size())):
                village.figures[i].node.scale = Vector3.ONE * lerpf(0.45, 1.0, clampf(float(inhabitants[i].age) / 16.0, 0, 1))
        village.live = live
        village.point = point
        village.info = info

func animate(delta: float) -> void:
    var running: bool = world.running or world.session.active
    if running: clock += delta
    var blend := 1.0 - exp(-delta * 12.0)
    for fighter in fighters.values():
        var f: Dictionary = fighter.info
        var p: Dictionary = fighter.figure
        var spot := Vector2(f.point[0], f.point[1])
        p.node.visible = world.sim.has_live_sight(spot)
        p.cargo.visible = f.get("laden", false)
        p.node.position = p.node.position.lerp(world.pos(spot.x, spot.y, 0.04), blend)
        p.node.rotation.y = lerp_angle(p.node.rotation.y, float(f.heading), blend)
        if f.armed:
            world.citizens.animate_soldier(p, f.action, clock, delta if running else 0.0)
        else:
            var swing := sin(clock * 7 + p.index) * 0.45 if f.action == "Marching" else 0.0
            p.ll.rotation.x = swing
            p.rl.rotation.x = -swing
            p.la.rotation.x = -swing
            p.ra.rotation.x = swing
    for battle in battles.values():
        var point: Vector2 = battle.point
        for i in range(battle.figures.size()):
            var p: Dictionary = battle.figures[i]
            var spot := point + Vector2(0.85 + float(i / 6) * 0.65, (i % 6 - 2.5) * 0.65)
            spot.x += sin(clock * 2.4 + i * 1.73) * 0.14
            p.node.position = world.pos(spot.x, spot.y, 0.04)
            p.node.rotation.y = -PI * 0.5
            world.citizens.animate_soldier(p, "Fighting", clock, delta if running else 0.0)
            if running and p.job == "Archers": projectile(p, world.pos(point.x - 0.85, spot.y, 1.0))
    for arrow in arrows.duplicate():
        if running: arrow.age += delta
        var t := minf(1.0, float(arrow.age) / 0.45)
        arrow.node.position = arrow.start.lerp(arrow.end, t) + Vector3.UP * sin(t * PI) * 0.8
        if t >= 1.0 or not world.sim.has_live_sight(Vector2(arrow.node.position.x, arrow.node.position.z)):
            arrow.node.queue_free()
            arrows.erase(arrow)
    for item in fallen.duplicate():
        if not world.sim.has_live_sight(item.point):
            item.figure.node.queue_free()
            fallen.erase(item)
            continue
        if running: item.age += delta
        item.figure.body.rotation.z = minf(PI * 0.5, item.age * 3.0)
        item.figure.body.position.y = -minf(0.65, item.age * 1.3)
        if item.age > 9:
            item.figure.node.scale *= exp(-delta * 2)
        if item.age > 11:
            item.figure.node.queue_free()
            fallen.erase(item)
    for village in villages.values():
        if not village.live: continue
        for p in village.figures:
            var military: bool = p.job in ["Militia", "Spearmen", "Archers"]
            var phase := fposmod(clock / 16.0 + p.index * 0.137, 1.0)
            var home: Vector2 = village.point + Vector2(-8 + p.index % 5 * 0.7, 4)
            var work: Vector2 = village.point + Vector2(-12, -5 + p.index % 6)
            if military: work = village.point + Vector2(-5, -3) + Vector2(p.index % 4, p.index % 3)
            elif p.job == "Gathering": work = village.point + Vector2(-13, 9) + Vector2(p.index % 4, 0)
            else:
                for b in village.info.buildings:
                    if (p.job == "Construction" and b.progress < 1) or (p.job == "Farming" and b.kind == "Field"):
                        work = village.point + Vector2(3.0 * b.q, sqrt(3.0) * 2 * (b.r + b.q * 0.5)) + Vector2(2.3, 0)
                        break
            var night_rest: bool = world.sim.is_night() and not military
            p.node.visible = not night_rest or p.index % 6 == int(world.sim.day) % 6
            var walking: bool = phase < 0.3 or phase > 0.75
            var spot: Vector2 = home.lerp(work, phase / 0.3) if phase < 0.3 else work.lerp(home, (phase - 0.75) / 0.25) if phase > 0.75 else work
            if p.job == "Resting" or night_rest:
                spot = home
                walking = false
            p.node.position = world.pos(spot.x, spot.y, 0.04)
            var direction := work - home if phase < 0.75 else home - work
            p.node.rotation.y = atan2(direction.x, direction.y)
            if military:
                world.citizens.animate_soldier(p, "Marching" if walking else "Training", clock, delta if running else 0.0)
            else:
                var swing := sin(clock * 7 + p.index) * 0.45 if walking and p.job != "Resting" else 0.0
                p.ll.rotation.x = swing
                p.rl.rotation.x = -swing
                p.ra.rotation.x = 0.0 if p.job == "Resting" or night_rest else -swing if walking else -0.7 + sin(clock * 4 + p.index) * 0.5
                p.la.rotation.x = swing
                p.tool.visible = not walking and p.job != "Resting" and not night_rest
                p.cargo.visible = not night_rest and phase > 0.75 and p.job in ["Logging", "Gathering", "Quarrying", "Farming"]

func projectile(p: Dictionary, destination: Vector3, actual_shot: bool = false) -> void:
    if not actual_shot and clock < float(p.get("next_arrow", 0)): return
    p.next_arrow = clock + 1.4 + (p.index % 3) * 0.15
    var node := Node3D.new()
    add_child(node)
    var start: Vector3 = p.node.global_position + Vector3.UP * 1.05
    world.beam(node, Vector3.ZERO, Vector3(0, 0, 0.45), 0.015, world.mats.wood)
    node.position = start
    node.rotation.y = atan2(destination.x - start.x, destination.z - start.z)
    arrows.append({"node": node, "start": start, "end": destination, "age": 0.0})
