extends Node3D

var world: Node3D
var fog: ShaderMaterial
var objects: Array = []
var timer := 0.0
var seen_revision := -1
var last_party := Vector2(INF, INF)
var marker := Node3D.new()
var nodes: Dictionary = {}
var cover: MeshInstance3D
var sights: ImageTexture

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
    if seen_revision != world.sim.exploration_revision or party.distance_to(last_party) > 0.4 or not world.sim.scout_missions.is_empty():
        redraw()

func redraw() -> void:
    if not is_instance_valid(world): return
    var sim = world.sim
    var party: Vector2 = sim.scout_position()
    seen_revision = sim.exploration_revision
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
