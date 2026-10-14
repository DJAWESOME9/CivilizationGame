extends Node3D

const Warfare = preload("res://scripts/warfare.gd")
var world: Node3D
var settlements: Dictionary = {}
var forces: Dictionary = {}
var timer := 0.0
var hovered_settlement := ""
var couriers: Dictionary = {}
var campaign_math = Warfare.new()
var animation_clock := 0.0
var battle_visuals: Node3D

func setup(scene: Node3D) -> void:
    world = scene
    battle_visuals = preload("res://scripts/battle_visuals.gd").new()
    world.add_child(battle_visuals)
    battle_visuals.setup(world)

func invalidate() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    battle_visuals.clear()
    settlements.clear()
    forces.clear()
    couriers.clear()

func caption(parent: Node3D) -> Label3D:
    var label := Label3D.new()
    label.position.y = 3.4
    label.font_size = 28
    label.outline_size = 6
    label.pixel_size = 0.025
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = false
    parent.add_child(label)
    return label

func refresh_settlements() -> void:
    for key in settlements.keys():
        if not world.sim.known_civilizations.has(key):
            settlements[key].node.queue_free()
            settlements.erase(key)
    for key in world.sim.known_civilizations:
        var info: Dictionary = world.sim.known_civilizations[key]
        var point := Vector2(info.point[0], info.point[1])
        var building_shapes: Array = []
        for building in info.buildings: building_shapes.append([building.kind, building.q, building.r, building.progress >= 1])
        var signature := str([info.point, building_shapes])
        if not settlements.has(key) or settlements[key].signature != signature:
            if settlements.has(key): settlements[key].node.queue_free()
            var root := Node3D.new()
            add_child(root)
            world.tent(point.x + 2, point.y + 5, -0.3)
            world.get_child(world.get_child_count() - 1).reparent(root)
            world.tent(point.x - 7, point.y + 5.7, 0.2)
            world.get_child(world.get_child_count() - 1).reparent(root)
            for building in info.buildings:
                var location := point + Vector2(4 + 3.0 * building.q, sqrt(3.0) * 2 * (building.r + building.q * 0.5))
                if building.progress >= 1 and building.kind in ["House", "Storehouse", "School", "Barracks", "Pottery Workshop", "Archive"]:
                    var home: Node3D = world.house(location.x, location.y, 0.15, 0.85)
                    home.reparent(root)
                elif building.progress >= 1 and building.kind in ["Carpenter Workshop", "Bathhouse"]:
                    var facility := Node3D.new()
                    root.add_child(facility)
                    facility.position = world.pos(location.x, location.y, 0.04)
                    world.craft_building_model(facility, building.kind)
                elif building.progress >= 1 and building.kind == "Wall":
                    var wall := Node3D.new()
                    root.add_child(wall)
                    wall.position = world.pos(location.x, location.y, 0.04)
                    world.stone_wall(wall)
                else:
                    world.box(root, world.pos(location.x, location.y, 0.15), Vector3(2.3, 0.3 if building.progress < 1 else 0.1, 2.3), world.mats.soil)
            var marker := Node3D.new()
            marker.position = world.pos(point.x, point.y)
            root.add_child(marker)
            settlements[key] = {"node": root, "label": caption(marker), "signature": signature}
        var live: bool = world.sim.has_live_sight(point)
        settlements[key].label.text = "%s\n%d people · %s" % [info.name, info.population, "in sight" if live else "seen %.1f days ago" % maxf(0.0, world.session.world_day - float(info.last_seen))]
        settlements[key].label.modulate = Color("fff0b9") if key == hovered_settlement else Color("dfd6ba") if live else Color("8d9a8b")

func refresh_forces() -> void:
    var visible: Dictionary = {}
    var origin := Vector2(world.sim.world_origin[0], world.sim.world_origin[1])
    for report in world.sim.known_armies.values(): visible[str(int(report.id))] = Warfare.public_enemy_report(report)
    for campaign in world.session.visible_campaigns:
        var info: Dictionary = campaign.duplicate(true)
        var point: Vector2 = campaign_math.campaign_point(info) - origin if info.own else Vector2(info.point[0], info.point[1])
        info.point = [point.x, point.y]
        info.last_seen = world.sim.day
        visible[str(int(info.id))] = info
    for key in forces.keys():
        if not visible.has(key):
            forces[key].node.queue_free()
            forces.erase(key)
    for key in visible:
        var info: Dictionary = visible[key]
        var signature := str([info.unit, info.count])
        if not forces.has(key) or forces[key].signature != signature:
            if forces.has(key): forces[key].node.queue_free()
            var root := Node3D.new()
            add_child(root)
            var figures: Array = []
            for i in range(mini(12, int(info.count))):
                var figure: Dictionary = world.citizens.make_person(i)
                figure.node.reparent(root)
                figure.job = "Militia" if info.unit == "Unknown" else info.unit
                world.citizens.equip(figure)
                figure.tool.show()
                figure.node.position = formation_position(i, mini(12, int(info.count)), info.get("formation", "Line"))
                figures.append(figure)
            world.beam(root, Vector3(0, 0, 0), Vector3(0, 2.8, 0), 0.035, world.mats.wood)
            world.box(root, Vector3(0.3, 2.5, 0), Vector3(0.6, 0.35, 0.035), world.mats.cloth)
            world.inspectable(root, {"kind": "Army", "own": info.own, "campaign": int(info.id), "army": int(info.get("army", -1))})
            root.position = world.pos(info.point[0], info.point[1], 0.04)
            forces[key] = {"node": root, "figures": figures, "label": caption(root), "signature": signature, "info": info, "live": false, "heading": 0.0}
        var at := Vector2(info.point[0], info.point[1])
        var live: bool = info.own or world.sim.has_live_sight(at)
        var identified: bool = info.own or info.get("intel_scouted", false)
        var unit_symbol: String = {"Militia": "⚔", "Spearmen": "↑", "Archers": "➶"}.get(info.unit, "◇")
        var phase_symbol: String = {"Marching": "→", "Moving": "→", "Returning": "↩", "Holding": "Ⅱ", "Fighting": "⚔", "Raiding": "▣", "Ready": "✓", "Recovering": "♥"}.get(info.phase, "◇")
        var badge := "%s %s  ·  %s" % [unit_symbol, str(info.count) if identified else "?", phase_symbol if live else "◷ %.1f" % maxf(0.0, world.session.world_day - float(info.last_seen))]
        if not info.own and identified: badge += "  ·  ◉ %.1f" % maxf(0.0, world.session.world_day - float(info.last_scouted))
        if info.phase == "Raiding" and not info.get("scene", {}).is_empty():
            var loot: Dictionary = info.scene.loot
            badge += "  ·  ● %.1f  ≋ %.1f  ◆ %.1f" % [loot.get("food", 0), loot.get("wood", 0), loot.get("stone", 0)]
        forces[key].label.text = badge
        forces[key].label.modulate = Color("e2c789") if info.own else Color("dca88d") if live else Color("8d9a8b")
        forces[key].info = info
        forces[key].live = live
        if not live: forces[key].node.position = world.pos(at.x, at.y, 0.04)
        if live and not info.own: forces[key].heading = float(info.get("heading", 0.0))
        if live and info.own:
            var route: Vector2 = Warfare.SITES[int(info.to_slot)] - Vector2(info.route_start[0], info.route_start[1])
            if info.phase == "Returning": route = Warfare.SITES[int(info.from_slot)] - Vector2(info.return_point[0], info.return_point[1])
            forces[key].heading = atan2(route.x, route.y)

func formation_position(index: int, count: int, formation: String) -> Vector3:
    var columns := mini(4, count)
    var spacing := 0.95 if formation == "Loose" else 0.6 if formation == "Shield wall" else 0.75
    var rows := ceili(float(count) / columns)
    var row := int(index / columns)
    var row_count := mini(columns, count - row * columns)
    return Vector3((index % columns - (row_count - 1) * 0.5) * spacing, 0, (row - (rows - 1) * 0.5) * spacing)

func animate_forces(delta: float) -> void:
    var blend := 1.0 - exp(-delta * 9.0)
    for force in forces.values():
        var info: Dictionary = force.info
        if not force.live: continue
        var target: Vector3 = world.pos(info.point[0], info.point[1], 0.04)
        force.node.position = force.node.position.lerp(target, blend)
        force.node.rotation.y = lerp_angle(force.node.rotation.y, force.heading, blend)
        if info.phase == "Fighting": force.node.rotation.y = PI * 0.5
        for figure in force.figures:
            var offset := formation_position(figure.index, force.figures.size(), info.get("formation", "Line"))
            if info.phase == "Fighting":
                offset = Vector3((figure.index % 6 - 2.5) * 0.65, 0, -0.75 - float(figure.index / 6) * 0.65 + sin(animation_clock * 2.4 + figure.index * 1.73) * 0.14)
            var loading := false
            if info.phase == "Raiding" and not info.get("scene", {}).is_empty():
                var storage: Array = info.scene.storage
                var source: Vector3 = world.pos(storage[0], storage[1], 0.04) + Vector3(2.3, 0, (figure.index % 3 - 1) * 0.65)
                var cycle := fposmod(animation_clock / 4.0 + figure.index * 0.17, 1.0)
                var fraction := cycle * 2.0 if cycle < 0.5 else (1.0 - cycle) * 2.0
                offset = force.node.to_local(target.lerp(source, fraction))
                loading = cycle >= 0.5
                var facing := target - source if loading else source - target
                figure.node.rotation.y = atan2(facing.x, facing.z) - force.node.rotation.y
            else: figure.node.rotation.y = 0.0
            figure.node.position = figure.node.position.lerp(offset, blend)
            var actual: Vector3 = force.node.to_global(figure.node.position)
            figure.node.position.y = world.surface_height(actual.x, actual.z) + 0.04 - force.node.position.y
            var mode := "Marching" if info.phase in ["Marching", "Returning", "Moving", "Raiding"] else "Fighting" if info.phase == "Fighting" else "Idle"
            world.citizens.animate_soldier(figure, mode, animation_clock, delta if world.running or world.session.active else 0.0)
            if mode == "Fighting" and figure.job == "Archers" and (world.running or world.session.active):
                battle_visuals.projectile(figure, target + Vector3(0.85, 1.0, figure.node.position.x))
            var loot: Dictionary = info.get("cargo", info.get("scene", {}).get("loot", {}))
            var laden: bool = float(loot.get("food", 0)) + float(loot.get("wood", 0)) + float(loot.get("stone", 0)) > 0
            figure.cargo.visible = laden and (loading or info.phase in ["Returning", "Moving"])
            if info.phase == "Raiding": figure.tool.hide()

func _process(delta: float) -> void:
    if not is_instance_valid(world): return
    if world.running or world.session.active: animation_clock += delta
    timer += delta
    if timer >= 0.25:
        timer = 0
        refresh_settlements()
        refresh_forces()
        battle_visuals.refresh()
    animate_forces(delta)
    battle_visuals.animate(delta)
    refresh_couriers(delta)
    arrange_captions()
    refresh_hover()

# Resolve projected overlaps along the camera's horizontal axis, including couriers
# and settlement captions. Reset anchors every frame so offsets never accumulate.
func arrange_captions() -> void:
    var labels: Array[Label3D] = []
    for settlement in settlements.values(): labels.append(settlement.label)
    for force in forces.values(): labels.append(force.label)
    for courier in couriers.values(): labels.append(courier.label)
    var occupied: Array[Rect2] = []
    for label in labels:
        label.position = Vector3(0, 3.4, 0)
        if world.camera.is_position_behind(label.global_position): continue
        var area := caption_rect(label).grow(6.0)
        var offset := 0.0
        # Each pass clears at least one earlier badge; repeat for newly met badges.
        for pass_index in range(occupied.size() + 1):
            var shifted := false
            for previous in occupied:
                if area.intersects(previous):
                    var step := previous.end.x - area.position.x + 1.0
                    offset += step
                    area.position.x += step
                    shifted = true
            if not shifted: break
        if offset > 0:
            var screen: Vector2 = world.camera.unproject_position(label.global_position)
            var depth: float = (label.global_position - world.camera.global_position).dot(-world.camera.global_transform.basis.z)
            label.global_position = world.camera.project_position(screen + Vector2(offset, 0), depth)
        occupied.append(area)

# Caption hit areas follow the billboard projection as the camera pans or zooms.
func caption_rect(label: Label3D) -> Rect2:
    if world.camera.is_position_behind(label.global_position): return Rect2()
    var center: Vector2 = world.camera.unproject_position(label.global_position)
    var lines := label.text.split("\n")
    var font: Font = label.font if label.font != null else ThemeDB.fallback_font
    var width := 0.0
    for line in lines: width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x)
    width = (width + label.outline_size * 2) * label.pixel_size
    var height: float = label.pixel_size * label.font_size * lines.size() * 1.3
    width *= label.global_transform.basis.x.length()
    height *= label.global_transform.basis.y.length()
    var right: Vector3 = world.camera.global_transform.basis.x * width * 0.5
    var up: Vector3 = world.camera.global_transform.basis.y * height * 0.5
    var half_width: float = center.distance_to(world.camera.unproject_position(label.global_position + right))
    var half_height: float = center.distance_to(world.camera.unproject_position(label.global_position + up))
    var size := Vector2(maxf(20, half_width * 2), maxf(18, half_height * 2))
    return Rect2(center - size * 0.5, size)

func pick_caption(screen: Vector2) -> Dictionary:
    for key in settlements:
        if caption_rect(settlements[key].label).has_point(screen):
            return {"kind": "Civilization", "slot": int(key)}
    for force in forces.values():
        if caption_rect(force.label).has_point(screen):
            return {"kind": "Army", "own": force.info.own, "campaign": int(force.info.id), "army": int(force.info.get("army", -1))}
    return {}

func refresh_hover() -> void:
    var previous := hovered_settlement
    hovered_settlement = ""
    var screen: Vector2 = get_viewport().get_mouse_position()
    if not world.management_open() and not world.pointer_over_panel(screen):
        for key in settlements:
            if caption_rect(settlements[key].label).has_point(screen):
                hovered_settlement = key
                break
    if previous != hovered_settlement: refresh_settlements()

func refresh_couriers(delta: float) -> void:
    var active: Dictionary = {}
    var origin := Vector2(world.sim.world_origin[0], world.sim.world_origin[1])
    for campaign in world.session.visible_campaigns:
        if not campaign.own: continue
        var messages: Array = campaign.get("messengers", [])
        if messages.is_empty(): continue
        var key := str(int(campaign.id))
        active[key] = true
        if not couriers.has(key):
            var figure: Dictionary = world.citizens.make_person(0)
            figure.node.reparent(self)
            figure.node.scale *= 1.1
            var title := caption(figure.node)
            title.text = "✉ →"
            title.modulate = Color("ffe6a3")
            couriers[key] = {"figure": figure, "label": title, "started": false}
        var courier: Dictionary = couriers[key]
        var point := Vector2(messages[0].point[0], messages[0].point[1]) - origin
        var destination: Vector3 = world.pos(point.x, point.y, 0.04)
        var node: Node3D = courier.figure.node
        var movement := destination - node.position
        if courier.started and movement.length() > 0.001: node.rotation.y = atan2(movement.x, movement.z)
        node.position = node.position.lerp(destination, 1.0 - exp(-delta * 12.0)) if courier.started else destination
        courier.started = true
        if world.running: world.citizens.animate_soldier(courier.figure, "Marching", animation_clock * 1.6, delta)
    for key in couriers.keys():
        if not active.has(key):
            couriers[key].figure.node.queue_free()
            couriers.erase(key)
