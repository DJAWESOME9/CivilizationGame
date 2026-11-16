extends Node3D

var world: Node3D
var fog: ShaderMaterial
var objects: Array = []
var timer := 0.0
var seen_revision := -1
var seen_home_radius := -1.0
var last_party := Vector2(INF, INF)
var marker := Node3D.new()
var nodes: Dictionary = {}
var cover: MeshInstance3D
var sights: ImageTexture
var scout_boats: Dictionary = {}
var river_covers: Array[MeshInstance3D] = []

func setup(scene: Node3D) -> void:
    world = scene
    for child in world.get_children():
        if child.has_meta("explorable"):
            objects.append(child)
    fog = ShaderMaterial.new()
    fog.shader = load("res://scripts/exploration.gdshader")
    cover = MeshInstance3D.new()
    cover.mesh = world.land_mesh.mesh
    cover.material_override = fog
    cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(cover)
    add_child(marker)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("d9bc77")
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for i in range(64):
        var a := i * TAU / 32.0
        var b := (i + 1) * TAU / 32.0
        world.beam(marker, Vector3(cos(a) * 0.9, 0.06, sin(a) * 0.9), Vector3(cos(b) * 0.9, 0.06, sin(b) * 0.9), 0.025, mat)
    marker.hide()
    redraw()

func invalidate() -> void:
    seen_revision = -1
    last_party = Vector2(INF, INF)
    marker.hide()
    redraw()

func select_land(point: Vector2) -> void:
    marker.position = world.pos(point.x, point.y, 0.08)
    marker.show()

func _process(delta: float) -> void:
    timer += delta
    if timer < 0.25: return
    timer = 0
    var party: Vector2 = world.sim.scout_position()
    if not is_equal_approx(seen_home_radius, world.sim.home_influence_radius()) or seen_revision != world.sim.exploration_revision or party.distance_to(last_party) > 0.4 or not world.sim.scout_missions.is_empty() or not world.sim.outposts.is_empty():
        redraw()
    refresh_scout_boats()

func redraw() -> void:
    if not is_instance_valid(world): return
    var sim = world.sim
    var party: Vector2 = sim.scout_position()
    seen_revision = sim.exploration_revision
    seen_home_radius = sim.home_influence_radius()
    last_party = party
    var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for x in range(64):
        for z in range(64):
            var point := Vector2(x * 3 - 94.5, z * 3 - 94.5)
            var known: bool = sim.explored.has("%d:%d" % [x, z])
            var live: bool = sim.has_live_sight(point)
            mask.set_pixel(x, z, Color(1 if known else 0, 1 if live else 0, 0, 1))
    if sights == null: sights = ImageTexture.create_from_image(mask)
    else: sights.update(mask)
    fog.set_shader_parameter("visibility_map", sights)
    while river_covers.size() > world.river_surface_nodes.size():
        var old_cover: MeshInstance3D = river_covers.pop_back()
        if is_instance_valid(old_cover): old_cover.queue_free()
    while river_covers.size() < world.river_surface_nodes.size():
        var river_cover := MeshInstance3D.new()
        river_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(river_cover)
        river_covers.append(river_cover)
    for i in range(world.river_surface_nodes.size()):
        var surface: MeshInstance3D = world.river_surface_nodes[i]
        var river_cover := river_covers[i]
        river_cover.mesh = surface.mesh
        river_cover.global_transform = surface.global_transform
        var cover_material := world.river_visibility_material.duplicate() as ShaderMaterial
        cover_material.set_shader_parameter("visibility_map", sights)
        cover_material.set_shader_parameter("river_overlay", true)
        river_cover.material_override = cover_material
    for object in objects:
        var point := Vector2(object.position.x, object.position.z)
        object.visible = not object.get_meta("resource_depleted", false) and sim.explored.has(sim.cell_key(point))
        if object.has_method("set_live_sight"):
            object.set_live_sight(sim.has_live_sight(point))

func replace_land() -> void:
    cover.mesh = world.land_mesh.mesh
    objects.clear()
    for child in world.get_children():
        if child.has_meta("explorable"): objects.append(child)
    invalidate()

func refresh_scout_boats() -> void:
    var active: Array = []
    for mission in world.sim.scout_missions:
        if not mission.get("boat", false): continue
        var key := str(mission.units[0])
        active.append(key)
        if not scout_boats.has(key):
            var new_hull := Node3D.new()
            add_child(new_hull)
            world.box(new_hull, Vector3(0, 0.12, 0), Vector3(1.0, 0.24, 2.0), world.mats.wood)
            for side in [-1.0, 1.0]:
                world.box(new_hull, Vector3(side * 0.48, 0.3, 0), Vector3(0.1, 0.35, 2.0), world.mats.wood)
            for seat in [-0.5, 0.0, 0.5]:
                world.box(new_hull, Vector3(0, 0.3, seat), Vector3(0.9, 0.1, 0.15), world.mats.wood)
            world.inspectable(new_hull, {"kind": "Scouting party", "mission_started": mission.started, "mission_units": mission.units.duplicate()})
            scout_boats[key] = new_hull
        var hull: Node3D = scout_boats[key]
        var point: Vector2 = world.sim.mission_position(mission)
        hull.position = Vector3(point.x, -0.18, point.y)
        var direction: Vector2 = world.sim.mission_direction(mission)
        hull.rotation.y = atan2(direction.x, direction.y)
        hull.visible = world.sim.point_on_river(point)
    for key in scout_boats.keys():
        if key not in active:
            scout_boats[key].queue_free()
            scout_boats.erase(key)
