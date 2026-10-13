extends Node3D
var updater: Node
var game_audio: Node
var music_volume := 55.0
var ambience_volume := 65.0
var effects_volume := 80.0

var session: Node
var multiplayer_screen: Control
var solo_time_controls: Array[Control] = []
var sim = preload("res://scripts/simulation.gd").new()
var running := false
var play_speed := 0.0
var build_choice := ""
var building_nodes := Node3D.new()
var visual_revision := -1
var hud_timer := 0.0
var save_timer := 0.0
var status_label: Label
var stock_label: Label
var research_button: Button
var resource_labels: Dictionary = {}
var resource_rate_labels: Dictionary = {}
var resource_panel: Control
var object_panel: Control
var top_date: Label
var civilization_title: Label
var top_storage: Label
var research_screen: Control
var citizens: Node3D
var population_screen: Control
var build_buttons: Dictionary = {}
var event_label: Label
var project_label: Label
var worker_label: Label
var emergency_food_toggle: CheckBox
var job_controls: Dictionary = {}
var ui_panels: Array[Control] = []
var feedback: Label
var play_button: Button
var panel_states: Dictionary = {}
var left_down := false
var drag_moved := false
var drag_screen := Vector2.ZERO
var drag_anchor := Vector3.ZERO
var drag_button := 0
var selected_land := Vector2.ZERO
var has_selected_land := false
var choosing_scout_destination := false
var exploration_label: Label
var scout_button: Button
var exploration: Node3D
var happiness_panel: Control
var happiness_button: Button
var settings_panel: Control
var master_volume := 100.0
var zoom_sensitivity := 1.0
var show_hex_lines := false
var fullscreen_preference := false
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var camera := Camera3D.new()
var focus := Vector3(-3.0, 0.0, 0.0)
var yaw := 0.32
var camera_size := 31.0
var dragging := false
var orbiting := false
var mats: Dictionary = {}
var hex_grid := Node3D.new()
var scenery_nodes: Array[Node] = []
var resource_deposits = preload("res://scripts/resource_deposits.gd").new()
var region_origin := Vector2.ZERO
var region_shared := false
var world_entities: Node3D
var season_seen := -1
var day_clock: Control
var sky_environment: Environment
var moonlight: DirectionalLight3D
var hearth_light: OmniLight3D
var hearth_flame: MeshInstance3D
var sunlight: DirectionalLight3D
var water_material: ShaderMaterial
var frame_count := 0
const ForestTree = preload("res://scripts/forest_tree.gd")
var land_mesh: MeshInstance3D
var intro_panel: PanelContainer
var intro_copy: Label
var intro_step := 0

func _ready() -> void:
    rng.seed = 72419
    noise.seed = 519
    noise.frequency = 0.052
    make_materials()
    make_light()
    var geometry_start := get_child_count()
    make_land()
    make_river()
    make_paths()
    make_village()
    make_forest()
    var before_resources := get_child_count()
    make_rocks()
    make_reeds()
    for i in range(before_resources, get_child_count()):
        get_child(i).set_meta("explorable", true)
    for i in range(geometry_start, get_child_count()): scenery_nodes.append(get_child(i))
    make_hex_grid()
    load_settings()
    add_child(camera)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.far = 650.0
    update_camera()
    if "--guest-profile" in OS.get_cmdline_user_args(): sim.save_path = "user://guest_settlement.json"
    if "--capture" not in OS.get_cmdline_user_args(): sim.load_game()
    if "--capture" in OS.get_cmdline_user_args() and "--winter" in OS.get_cmdline_user_args(): sim.day = 270
    if "--capture" in OS.get_cmdline_user_args() and "--night" in OS.get_cmdline_user_args(): sim.day += 14.0 / 24.0
    if "--capture" in OS.get_cmdline_user_args() and "--sunset" in OS.get_cmdline_user_args(): sim.day += 10.0 / 24.0
    sim.tick(0)
    resource_deposits.rebuild(self)
    add_child(building_nodes)
    make_ui()
    exploration = preload("res://scripts/exploration.gd").new()
    add_child(exploration)
    exploration.setup(self)
    refresh_game()
    citizens = preload("res://scripts/citizens.gd").new()
    add_child(citizens)
    citizens.setup(self)
    session = preload("res://scripts/multiplayer_session.gd").new()
    session.name = "Session"
    add_child(session)
    session.setup(self)
    multiplayer_screen = preload("res://scripts/multiplayer_screen.gd").new()
    settings_panel.get_parent().add_child(multiplayer_screen)
    multiplayer_screen.setup(self)
    world_entities = preload("res://scripts/world_entities.gd").new()
    add_child(world_entities)
    world_entities.setup(self)
    configure_world_map()
    if "--multiplayer" in OS.get_cmdline_user_args(): multiplayer_screen.show()
    if "--research" in OS.get_cmdline_user_args(): research_screen.show()
    if "--population" in OS.get_cmdline_user_args(): population_screen.show()
    if "--capture" not in OS.get_cmdline_user_args() and not sim.has_seen_intro:
        show_intro()
    if "--resources" in OS.get_cmdline_user_args(): resource_panel.open_resource("food")
    if "--happiness" in OS.get_cmdline_user_args(): happiness_panel.show()
    if "--settings" in OS.get_cmdline_user_args(): settings_panel.show()
    if "--collapsed" in OS.get_cmdline_user_args():
        for title in panel_states: set_panel_collapsed(title, true)
    get_tree().auto_accept_quit = false
    updater = preload("res://scripts/game_updater.gd").new()
    add_child(updater)
    updater.setup(self)
    updater.changed.connect(settings_panel.refresh_updates)
    settings_panel.refresh_updates()
    game_audio = preload("res://scripts/game_audio.gd").new()
    add_child(game_audio)
    game_audio.setup(self)

func ground_height(x: float, z: float) -> float:
    var global_point := Vector2(x, z) + region_origin
    var river_x := 10.0 + sin(global_point.y * 0.095) * 3.0
    var river_distance := absf(global_point.x - river_x)
    var h := noise.get_noise_2d(global_point.x, global_point.y) * 2.8 + 0.5
    var clearing := 1.0 - smoothstep(6.0, 15.0, Vector2(x + 4.0, z).length())
    if region_shared:
        for site in preload("res://scripts/warfare.gd").SITES:
            clearing = maxf(clearing, 1.0 - smoothstep(6.0, 15.0, global_point.distance_to(site)))
    h = lerpf(h, 0.5, clearing)
    if river_distance < 3.8:
        h = lerpf(-0.6, h, smoothstep(2.4, 3.8, river_distance))
    return h

func pos(x: float, z: float, lift: float = 0.0) -> Vector3:
    return Vector3(x, surface_height(x, z) + lift, z)

func surface_height(x: float, z: float) -> float:
    # Match the actual triangles of the one-unit terrain mesh, not a fresh
    # noise sample between vertices (which can fall above/below that mesh).
    var xx := floorf(x)
    var zz := floorf(z)
    var tx := x - xx
    var tz := z - zz
    var a := ground_height(xx, zz)
    var b := ground_height(xx + 1, zz)
    var c := ground_height(xx, zz + 1)
    var d := ground_height(xx + 1, zz + 1)
    if tx + tz <= 1.0:
        return a + (b - a) * tx + (c - a) * tz
    return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)

func textured_material(color: Color, scale_value: float, ridged: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.92
    var n := FastNoiseLite.new()
    n.seed = 185
    n.frequency = 0.06
    n.fractal_octaves = 4
    var tex := NoiseTexture2D.new()
    tex.width = 256
    tex.height = 256
    tex.noise = n
    tex.seamless = true
    var ramp := Gradient.new()
    ramp.set_color(0, Color(0.48, 0.44, 0.37))
    ramp.set_color(1, Color(1.0, 0.97, 0.84))
    tex.color_ramp = ramp
    m.albedo_texture = tex
    m.uv1_triplanar = true
    m.uv1_scale = Vector3(scale_value, scale_value * (4.0 if ridged else 1.0), scale_value)
    return m

func make_materials() -> void:
    mats.grass = ShaderMaterial.new()
    mats.grass.shader = load("res://scripts/terrain.gdshader")
    mats.grass.set_shader_parameter("meadow", load("res://assets/meadow.png"))
    mats.soil = textured_material(Color("9a7954"), 0.6)
    mats.soil.cull_mode = BaseMaterial3D.CULL_DISABLED
    mats.plaster = textured_material(Color("dfc99d"), 1.8)
    mats.wood = textured_material(Color("725038"), 1.3, true)
    mats.thatch = textured_material(Color("92764f"), 2.0, true)
    mats.stone = textured_material(Color("95958a"), 1.4)
    mats.cloth = textured_material(Color("d6c6a6"), 3.0)
    mats.dark = textured_material(Color("302d22"), 1.5)
    mats.reed = textured_material(Color("92995a"), 3.0)

func make_light() -> void:
    var sun := DirectionalLight3D.new()
    sunlight = sun
    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_color = Color(1.0, 0.91, 0.73)
    sun.light_energy = 0.85
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100
    sun.shadow_bias = 0.04
    add_child(sun)
    moonlight = DirectionalLight3D.new()
    moonlight.rotation_degrees = Vector3(-45, 135, 0)
    moonlight.light_color = Color("94b7ed")
    moonlight.light_energy = 0
    add_child(moonlight)
    var env := Environment.new()
    sky_environment = env
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("9eafa1")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b5c6cc")
    env.ambient_light_energy = 0.48
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)

func mesh_from_triangles(vertices: PackedVector3Array, material: Material, parent: Node3D = self) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for v in vertices:
        st.set_uv(Vector2(v.x, v.z) * 0.15)
        st.add_vertex(v)
    st.generate_normals()
    var instance := MeshInstance3D.new()
    instance.mesh = st.commit()
    instance.material_override = material
    parent.add_child(instance)
    return instance

func make_land() -> void:
    var vertices := PackedVector3Array()
    for x in range(-96, 96):
        for z in range(-96, 96):
            var a := pos(x, z)
            var b := pos(x + 1, z)
            var c := pos(x, z + 1)
            var d := pos(x + 1, z + 1)
            vertices.append_array([a, b, c, b, d, c])
    land_mesh = mesh_from_triangles(vertices, mats.grass)

func make_river() -> void:
    var water := ShaderMaterial.new()
    water.shader = load("res://scripts/water.gdshader")
    water_material = water
    var vertices := PackedVector3Array()
    for z in range(-96, 96):
        var x1 := 10.0 + sin((z + region_origin.y) * 0.095) * 3.0 - region_origin.x
        var x2 := 10.0 + sin((z + 1 + region_origin.y) * 0.095) * 3.0 - region_origin.x
        var a := Vector3(x1 - 2.45, -0.18, z)
        var b := Vector3(x1 + 2.45, -0.18, z)
        var c := Vector3(x2 - 2.45, -0.18, z + 1)
        var d := Vector3(x2 + 2.45, -0.18, z + 1)
        vertices.append_array([a, b, c, b, d, c])
    mesh_from_triangles(vertices, water)

func box(parent: Node3D, location: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size_value
    item.mesh = mesh
    item.position = location
    item.material_override = material
    parent.add_child(item)
    return item

func cylinder(parent: Node3D, location: Vector3, bottom: float, top: float, height_value: float, material: Material, sides: int = 12) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = bottom
    mesh.top_radius = top
    mesh.height = height_value
    mesh.radial_segments = sides
    item.mesh = mesh
    item.position = location
    item.material_override = material
    parent.add_child(item)
    return item

func sphere(parent: Node3D, location: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    item.mesh = mesh
    item.position = location
    item.scale = size_value
    item.material_override = material
    parent.add_child(item)
    return item

func beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
    var item := cylinder(parent, (a + b) * 0.5, radius, radius * 0.9, a.distance_to(b), material, 8)
    var direction := (b - a).normalized()
    item.quaternion = Quaternion(Vector3.UP, direction)

func ribbon(points: Array[Vector2], width: float, material: Material, lift: float = 0.04) -> void:
    var vertices := PackedVector3Array()
    for i in range(points.size() - 1):
        var start := points[i]
        var end := points[i + 1]
        var normal := (end - start).normalized().orthogonal() * width * 0.5
        var steps := maxi(1, int(start.distance_to(end) * 2))
        for j in range(steps):
            var p1 := start.lerp(end, float(j) / steps)
            var p2 := start.lerp(end, float(j + 1) / steps)
            var a := pos(p1.x + normal.x, p1.y + normal.y, lift)
            var b := pos(p1.x - normal.x, p1.y - normal.y, lift)
            var c := pos(p2.x + normal.x, p2.y + normal.y, lift)
            var d := pos(p2.x - normal.x, p2.y - normal.y, lift)
            vertices.append_array([a, b, c, b, d, c])
    mesh_from_triangles(vertices, material)

func make_paths() -> void:
    ribbon([Vector2(-14, 8), Vector2(-9, 4), Vector2(-4, 1), Vector2(1, 3), Vector2(6, 6)], 1.0, mats.soil)
    ribbon([Vector2(-9, -7), Vector2(-7, -3), Vector2(-4, 1), Vector2(-3, 9)], 0.8, mats.soil)
    ribbon([Vector2(-4, 1), Vector2(0, -3), Vector2(6, -5)], 0.7, mats.soil)

func roof(parent: Node3D, w: float, d: float, wall: float, peak: float, material: Material) -> void:
    var a := Vector3(-w, wall, -d)
    var b := Vector3(w, wall, -d)
    var c := Vector3(-w, wall, d)
    var e := Vector3(w, wall, d)
    var f := Vector3(0, peak, -d)
    var g := Vector3(0, peak, d)
    var vertices := PackedVector3Array([a, f, c, f, g, c, f, b, g, b, e, g, a, b, f, c, g, e])
    var m := material.duplicate() as StandardMaterial3D
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh_from_triangles(vertices, m, parent)
    beam(parent, f, g, 0.07, mats.wood)

func house(x: float, z: float, angle: float, scale_value: float = 1.0) -> Node3D:
    var home := Node3D.new()
    home.position = pos(x, z)
    home.rotation.y = angle
    home.scale = Vector3.ONE * scale_value
    add_child(home)
    box(home, Vector3(0, 0.18, 0), Vector3(2.55, 0.36, 2.8), mats.stone)
    box(home, Vector3(0, 0.95, 0), Vector3(2.3, 1.55, 2.5), mats.plaster)
    roof(home, 1.5, 1.65, 1.65, 2.7, mats.thatch)
    for x_post in [-1.1, 1.1]:
        for z_post in [-1.2, 1.2]:
            box(home, Vector3(x_post, 0.95, z_post), Vector3(0.13, 1.65, 0.13), mats.wood)
    box(home, Vector3(0, 0.66, 1.26), Vector3(0.64, 1.06, 0.08), mats.dark)
    for x_post in [-0.36, 0.36]:
        box(home, Vector3(x_post, 0.75, 1.32), Vector3(0.09, 1.25, 0.1), mats.wood)
    box(home, Vector3(0, 1.32, 1.33), Vector3(0.82, 0.11, 0.12), mats.wood)
    box(home, Vector3(1.16, 1.15, 0.1), Vector3(0.06, 0.44, 0.53), mats.dark)
    for i in range(4):
        box(home, Vector3(1.20, 1.15, -0.1 + i * 0.14), Vector3(0.08, 0.5, 0.05), mats.wood)
    # Thatch battens and roof-edge bundles retain detail at close zoom.
    for i in range(12):
        var zz := -1.6 + i * 0.29
        beam(home, Vector3(-1.5, 1.67, zz), Vector3(0, 2.72, zz), 0.018, mats.thatch)
        beam(home, Vector3(0, 2.72, zz), Vector3(1.5, 1.67, zz), 0.018, mats.thatch)
    cylinder(home, Vector3(1.7, 0.3, 0.8), 0.23, 0.18, 0.6, mats.soil)

    return home

func tent(x: float, z: float, angle: float) -> void:
    var item := Node3D.new()
    item.position = pos(x, z)
    item.rotation.y = angle
    add_child(item)
    roof(item, 1.1, 1.4, 0.15, 1.55, mats.cloth)
    for zz in [-1.5, 1.5]:
        beam(item, Vector3(0, 0, zz), Vector3(0, 1.65, zz), 0.05, mats.wood)
    for xx in [-1.3, 1.3]:
        beam(item, Vector3(xx, 0.08, 1.6), Vector3(0, 1.55, 1.4), 0.012, mats.wood)

func make_village() -> void:
    tent(-2, 5.0, -0.3)
    inspectable(get_child(get_child_count() - 1), {"kind": "Starting tent"})
    tent(-11, 5.7, 0.2)
    inspectable(get_child(get_child_count() - 1), {"kind": "Starting tent"})
    # Supply cache: racks, timber, jars, stacked sacks and a fabric shade.
    var cache := Node3D.new()
    cache.position = pos(-6.0, 0.0)
    add_child(cache)
    inspectable(cache, {"kind": "Supply cache"})
    for i in range(6):
        var log_item := cylinder(cache, Vector3(-0.5 + (i % 3) * 0.25, 0.18 + (i / 3) * 0.23, 0), 0.12, 0.12, 1.5, mats.wood)
        log_item.rotation.z = PI * 0.5
    for i in range(5):
        sphere(cache, Vector3(0.9 + (i % 2) * 0.4, 0.27 + (i / 2) * 0.24, 0.1), Vector3(0.32, 0.22, 0.25), mats.cloth)
    for xx in [-1.3, 1.5]:
        for zz in [-0.8, 0.8]:
            beam(cache, Vector3(xx, 0, zz), Vector3(xx, 1.7, zz), 0.045, mats.wood)
    box(cache, Vector3(0, 1.7, 0), Vector3(3.1, 0.04, 1.9), mats.cloth)
    for i in range(12):
        var a := i * TAU / 12
        var stone := sphere(self, pos(-3 + cos(a) * 0.68, 1.5 + sin(a) * 0.68, 0.12), Vector3(0.19, 0.12, 0.15), mats.stone)
        inspectable(stone, {"kind": "Campfire"})
    for i in range(3):
        beam(self, pos(-3.4, 1.1 + i * 0.18, 0.12), pos(-2.7, 1.7 - i * 0.13, 0.12), 0.06, mats.wood)
        inspectable(get_child(get_child_count() - 1), {"kind": "Campfire"})
    make_hearth()
    make_cart(-8.5, 2.6)
    make_cart(0.5, 3.5)

func make_cart(x: float, z: float) -> void:
    var cart := Node3D.new()
    cart.position = pos(x, z)
    cart.rotation.y = 0.6
    add_child(cart)
    inspectable(cart, {"kind": "Cart"})
    box(cart, Vector3(0, 0.5, 0), Vector3(0.9, 0.12, 1.3), mats.wood)
    for xx in [-0.48, 0.48]:
        for j in range(3):
            box(cart, Vector3(xx, 0.58 + j * 0.13, 0), Vector3(0.07, 0.07, 1.3), mats.wood)
        var wheel := cylinder(cart, Vector3(xx * 1.3, 0.34, 0.2), 0.34, 0.34, 0.08, mats.wood)
        wheel.rotation.z = PI * 0.5
        beam(cart, Vector3(xx * 0.7, 0.47, -0.6), Vector3(xx * 0.7, 0.3, -1.8), 0.04, mats.wood)

func tree(x: float, z: float, size_value: float) -> void:
    var plant := ForestTree.new()
    plant.setup(pos(x, z), size_value, int((x + region_origin.x) * 7381 + (z + region_origin.y) * 1933))
    add_child(plant)
    inspectable(plant, {"kind": "Oak tree"})

func make_forest() -> void:
    var forest_rng := RandomNumberGenerator.new()
    forest_rng.seed = 72419
    for i in range(1200):
        var x := forest_rng.randf_range(-170, 95) - region_origin.x
        var z := forest_rng.randf_range(-125, 125) - region_origin.y
        var tree_size := forest_rng.randf_range(0.65, 1.5)
        if absf(x) > 92 or absf(z) > 92: continue
        var near_camp := Vector2(x + 4, z).length() < 13.5
        if region_shared:
            for site in preload("res://scripts/warfare.gd").SITES:
                if (Vector2(x, z) + region_origin).distance_to(site) < 13.5: near_camp = true
        if near_camp: continue
        if Vector2(x + 4, z).length() < 13.5 or absf(x + region_origin.x - (10 + sin((z + region_origin.y) * 0.095) * 3)) < 4.6:
            continue
        tree(x, z, tree_size)
    tree(-13.5, -5.5, 0.95)
    tree(3.9, -4, 0.75)
    tree(-14.5, 7, 0.8)

func make_rocks() -> void:
    for i in range(38):
        var x := rng.randf_range(-24, -15)
        var z := rng.randf_range(-18, -7)
        var rock := sphere(self, pos(x, z, rng.randf_range(0.1, 0.5)), Vector3(rng.randf_range(0.35, 1.0), rng.randf_range(0.4, 1.4), rng.randf_range(0.4, 1.0)), mats.stone)
        rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
        inspectable(rock, {"kind": "Stone deposit"})
    for i in range(24):
        var z := rng.randf_range(-25, 25)
        var x := 10 + sin((z + region_origin.y) * 0.095) * 3 - region_origin.x + (3.2 if i % 2 == 0 else -3.2)
        var stone := sphere(self, pos(x, z, 0.12), Vector3(0.35, 0.22, 0.3), mats.stone)
        inspectable(stone, {"kind": "River stone"})

func make_reeds() -> void:
    for i in range(110):
        var z := rng.randf_range(-25, 25)
        var x := 10 + sin((z + region_origin.y) * 0.095) * 3 - region_origin.x + rng.randf_range(2.8, 3.5) * (1 if i % 2 == 0 else -1)
        var p := pos(x, z)
        beam(self, p, p + Vector3(0.07, rng.randf_range(0.4, 0.85), 0.03), 0.018, mats.reed)
        inspectable(get_child(get_child_count() - 1), {"kind": "Reeds", "location": Vector2(x, z)})

func make_hex_grid() -> void:
    add_child(hex_grid)
    hex_grid.visible = false
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.89, 0.84, 0.65, 0.38)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var vertices := PackedVector3Array()
    for edge in hex_edges():
        var a: Vector2 = edge[0]
        var b: Vector2 = edge[1]
        var normal := (b - a).normalized().orthogonal() * 0.018
        var steps := 12
        for j in range(steps):
            var p1 := a.lerp(b, float(j) / steps)
            var p2 := a.lerp(b, float(j + 1) / steps)
            vertices.append_array([
                grid_point(p1 + normal), grid_point(p1 - normal), grid_point(p2 + normal),
                grid_point(p1 - normal), grid_point(p2 - normal), grid_point(p2 + normal)
            ])
    var mesh := mesh_from_triangles(vertices, mat, hex_grid)
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func grid_point(point: Vector2) -> Vector3:
    # Keep the overlay above water as well as land, including the wave crest.
    return Vector3(point.x, maxf(surface_height(point.x, point.y), -0.15) + 0.045, point.y)

func hex_edges() -> Array:
    var edges: Array = []
    var seen: Dictionary = {}
    for q in range(-6, 7):
        for r in range(-6, 7):
            var center := Vector2(3.0 * q, sqrt(3.0) * 2.0 * (r + q * 0.5))
            for i in range(6):
                var a := center + Vector2(cos(i * TAU / 6), sin(i * TAU / 6)) * 2.0
                var b := center + Vector2(cos((i + 1) * TAU / 6), sin((i + 1) * TAU / 6)) * 2.0
                var aa := Vector2i(roundi(a.x * 1000), roundi(a.y * 1000))
                var bb := Vector2i(roundi(b.x * 1000), roundi(b.y * 1000))
                var key := "%s:%s" % [aa, bb] if aa.x < bb.x or (aa.x == bb.x and aa.y < bb.y) else "%s:%s" % [bb, aa]
                if not seen.has(key):
                    seen[key] = true
                    edges.append([a, b])
    return edges

func update_camera() -> void:
    camera.size = camera_size
    var distance_scale := maxf(1.0, camera_size / 45.0)
    camera.position = focus + Vector3(sin(yaw) * 37, 25, cos(yaw) * 37) * distance_scale
    camera.look_at(focus)

func zoom_by(amount: float) -> void:
    camera_size = clampf(camera_size * exp(amount * zoom_sensitivity), 10, 185)
    update_camera()

func reset_camera() -> void:
    focus = Vector3(-3, 0, 0)
    yaw = 0.32
    # Start with more of the regional map in view while keeping the settlement legible.
    camera_size = 42
    update_camera()

func refresh_hex_grid() -> void:
    hex_grid.visible = show_hex_lines or not build_choice.is_empty()

func set_hex_lines(value: bool) -> void:
    show_hex_lines = value
    refresh_hex_grid()
    save_settings()

func apply_audio_volume() -> void:
    AudioServer.set_bus_mute(0, master_volume <= 0)
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume / 100.0, 0.0001)))
    for bus_name in ["Music", "Ambience", "Effects"]:
        var index := AudioServer.get_bus_index(bus_name)
        if index < 0: continue
        var level: float = music_volume if bus_name == "Music" else ambience_volume if bus_name == "Ambience" else effects_volume
        AudioServer.set_bus_mute(index, level <= 0)
        AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level / 100.0, 0.0001)))

func load_settings() -> void:
    var preferences := ConfigFile.new()
    if preferences.load("user://settings.cfg") == OK:
        master_volume = clampf(float(preferences.get_value("audio", "master_volume", 100.0)), 0, 100)
        music_volume = clampf(float(preferences.get_value("audio", "music_volume", 55.0)), 0, 100)
        ambience_volume = clampf(float(preferences.get_value("audio", "ambience_volume", 65.0)), 0, 100)
        effects_volume = clampf(float(preferences.get_value("audio", "effects_volume", 80.0)), 0, 100)
        zoom_sensitivity = clampf(float(preferences.get_value("camera", "zoom_sensitivity", 1.0)), 0.5, 2.0)
        show_hex_lines = bool(preferences.get_value("display", "hex_lines", false))
        fullscreen_preference = bool(preferences.get_value("display", "fullscreen", false))
    apply_audio_volume()
    refresh_hex_grid()
    if fullscreen_preference and "--capture" not in OS.get_cmdline_user_args(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings() -> void:
    if "--capture" in OS.get_cmdline_user_args(): return
    var preferences := ConfigFile.new()
    preferences.set_value("audio", "master_volume", master_volume)
    preferences.set_value("audio", "music_volume", music_volume)
    preferences.set_value("audio", "ambience_volume", ambience_volume)
    preferences.set_value("audio", "effects_volume", effects_volume)
    preferences.set_value("camera", "zoom_sensitivity", zoom_sensitivity)
    preferences.set_value("display", "hex_lines", show_hex_lines)
    preferences.set_value("display", "fullscreen", fullscreen_preference)
    preferences.save("user://settings.cfg")

func management_open() -> bool:
    return (is_instance_valid(multiplayer_screen) and multiplayer_screen.visible) or research_screen.visible or population_screen.visible or happiness_panel.visible or resource_panel.visible or settings_panel.visible or object_panel.visible

func inspectable(node: Node3D, info: Dictionary) -> void:
    node.set_meta("inspection", info)
    node.add_to_group("inspectable")

func mesh_hit_distance(node: Node3D, origin: Vector3, direction: Vector3) -> float:
    if not node.is_visible_in_tree(): return INF
    var nearest := INF
    if node is MeshInstance3D and node.mesh != null:
        var inverse := node.global_transform.affine_inverse()
        var hit = node.mesh.get_aabb().intersects_ray(inverse * origin, inverse.basis * direction)
        if hit is Vector3:
            nearest = origin.distance_to(node.global_transform * hit)
    for child in node.get_children():
        if child is Node3D:
            nearest = minf(nearest, mesh_hit_distance(child, origin, direction))
    return nearest

func pick_object(screen: Vector2) -> Dictionary:
    var origin := camera.project_ray_origin(screen)
    var direction := camera.project_ray_normal(screen)
    var nearest := INF
    var result: Dictionary = {}
    for node in get_tree().get_nodes_in_group("inspectable"):
        if not is_ancestor_of(node) or node.is_queued_for_deletion(): continue
        var distance := mesh_hit_distance(node, origin, direction)
        if distance < nearest:
            nearest = distance
            result = node.get_meta("inspection").duplicate(true)
            result["point"] = result.get("location", Vector2(node.global_position.x, node.global_position.z))
    return result

func ground_point(screen: Vector2) -> Vector3:
    var ray := camera.project_ray_origin(screen)
    var direction := camera.project_ray_normal(screen)
    var hit = Plane(Vector3.UP, 0.5).intersects_ray(ray, direction)
    return hit if hit is Vector3 else focus

func clamp_focus() -> void:
    focus.x = clampf(focus.x, -85, 85)
    focus.z = clampf(focus.z, -85, 85)

func begin_scout_selection() -> void:
    object_panel.hide()
    build_choice = ""
    choosing_scout_destination = true
    has_selected_land = false
    exploration.marker.hide()
    feedback.text = "Click a destination outside camp on the map. Drag to pan; Esc cancels."
    refresh_hex_grid()
    refresh_game()

func select_scout_land(point: Vector2) -> void:
    selected_land = point
    has_selected_land = true
    choosing_scout_destination = false
    exploration.select_land(point)
    refresh_game()

func dispatch_scouts(point: Vector2) -> String:
    var message := order("scout", [point])
    feedback.text = message
    if message.begins_with("Scouts dispatched.") or message == "Order sent to the host.":
        has_selected_land = false
        choosing_scout_destination = false
        exploration.marker.hide()
    refresh_game()
    return message

func _input(event: InputEvent) -> void:
    if is_instance_valid(object_panel) and object_panel.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            object_panel.hide()
            get_viewport().set_input_as_handled()
            return
    if is_instance_valid(multiplayer_screen) and multiplayer_screen.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            multiplayer_screen.hide()
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(settings_panel) and settings_panel.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            settings_panel.hide()
            get_viewport().set_input_as_handled()
        return
    # Finish drags even when the pointer has crossed a panel.
    if event is InputEventMouseButton and not event.pressed:
        if event.button_index == drag_button:
            var click := left_down and not drag_moved
            dragging = false
            left_down = false
            drag_button = 0
            if click and not pointer_over_panel() and not research_screen.visible and not population_screen.visible and not happiness_panel.visible and not resource_panel.visible:
                if not build_choice.is_empty(): place_building(event.position)
                else:
                    var object := {} if choosing_scout_destination else pick_object(event.position)
                    if not object.is_empty():
                        object_panel.open_object(object)
                        return
                    var point := ground_point(event.position)
                    select_scout_land(Vector2(clampf(point.x, -88, 88), clampf(point.z, -88, 88)))
                    object_panel.open_object({"kind": "Land", "point": selected_land})
            return
        if event.button_index == MOUSE_BUTTON_MIDDLE: orbiting = false
    if is_instance_valid(resource_panel) and resource_panel.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            resource_panel.hide()
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(happiness_panel) and happiness_panel.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            happiness_panel.hide()
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(population_screen) and population_screen.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            population_screen.hide()
            get_viewport().set_input_as_handled()
        return
    if is_instance_valid(research_screen) and research_screen.visible:
        if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
            research_screen.hide()
            get_viewport().set_input_as_handled()
        return
    if get_viewport().gui_get_focus_owner() is LineEdit: return
    if event is InputEventMouseMotion and dragging:
        if left_down and event.position.distance_to(drag_screen) > 6: drag_moved = true
        if not left_down or drag_moved:
            focus += drag_anchor - ground_point(event.position)
            clamp_focus()
            update_camera()
        get_viewport().set_input_as_handled()
        return
    if pointer_over_panel() and (event is InputEventPanGesture or event is InputEventMagnifyGesture or event is InputEventMouseButton): return
    if event is InputEventPanGesture:
        zoom_by(event.delta.y * 0.045)
        get_viewport().set_input_as_handled()
        return
    if event is InputEventMagnifyGesture:
        if event.factor > 0: zoom_by(-log(event.factor))
        get_viewport().set_input_as_handled()
        return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            var amount := absf(event.factor) if not is_zero_approx(event.factor) else 1.0
            zoom_by(amount * (-0.105 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.105))
            get_viewport().set_input_as_handled()
        elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
            dragging = true
            drag_button = event.button_index
            left_down = event.button_index == MOUSE_BUTTON_LEFT
            drag_moved = false
            drag_screen = event.position
            drag_anchor = ground_point(event.position)
        elif event.button_index == MOUSE_BUTTON_MIDDLE: orbiting = true
    if event is InputEventMouseMotion and orbiting:
        yaw -= event.relative.x * 0.005
        update_camera()
    if event is InputEventKey and event.pressed:
        if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]: zoom_by(-0.105)
        if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]: zoom_by(0.105)
        if event.keycode == KEY_H: set_hex_lines(not show_hex_lines)
        if event.keycode == KEY_TAB:
            var all_closed := true
            for state in panel_states.values():
                if state.panel.visible and state.body.visible: all_closed = false
            for title in panel_states: set_panel_collapsed(title, not all_closed)
            get_viewport().set_input_as_handled()
        if event.keycode == KEY_R: reset_camera()
        if event.keycode == KEY_ESCAPE:
            build_choice = ""
            choosing_scout_destination = false
            feedback.text = "Placement cancelled."
            refresh_hex_grid()

func _process(delta: float) -> void:
    if running and (not is_instance_valid(session) or (not session.active and not session.connecting)):
        sim.advance(delta * (sim.days_per_real_day / 86400.0 if play_speed == 0 else play_speed))
    hud_timer += delta
    save_timer += delta
    if hud_timer >= 0.3:
        hud_timer = 0
        refresh_game()
    if save_timer >= 15 and "--capture" not in OS.get_cmdline_user_args():
        save_timer = 0
        sim.save_game()
    var direction := Vector2.ZERO
    if not management_open():
        if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
        if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
        if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
        if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
        if Input.is_physical_key_pressed(KEY_Q): yaw += delta * 0.6
        if Input.is_physical_key_pressed(KEY_E): yaw -= delta * 0.6
    if direction != Vector2.ZERO:
        var right := camera.global_basis.x
        focus += (right * direction.x + Vector3(-right.z, 0, right.x) * direction.y) * delta * camera_size * 0.3
        clamp_focus()
    update_camera()
    update_daylight()
    frame_count += 1
    if frame_count == 1 and "--close" in OS.get_cmdline_user_args():
        camera_size = 16
        update_camera()
    if frame_count == 1 and "--hex" in OS.get_cmdline_user_args():
        hex_grid.visible = true
    if frame_count == 100 and "--capture" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        var capture_path := "res://captures/settlement.png"
        if "--close" in OS.get_cmdline_user_args(): capture_path = "res://captures/close.png"
        if "--hex" in OS.get_cmdline_user_args(): capture_path = "res://captures/hexes.png"
        if "--research" in OS.get_cmdline_user_args(): capture_path = "res://captures/research.png"
        if "--population" in OS.get_cmdline_user_args(): capture_path = "res://captures/population.png"
        if "--collapsed" in OS.get_cmdline_user_args(): capture_path = "res://captures/collapsed.png"
        if "--resources" in OS.get_cmdline_user_args(): capture_path = "res://captures/resources.png"
        if "--happiness" in OS.get_cmdline_user_args(): capture_path = "res://captures/happiness.png"
        if "--settings" in OS.get_cmdline_user_args(): capture_path = "res://captures/settings.png"
        if "--multiplayer" in OS.get_cmdline_user_args(): capture_path = "res://captures/multiplayer.png"
        if "--winter" in OS.get_cmdline_user_args(): capture_path = "res://captures/winter.png"
        if "--night" in OS.get_cmdline_user_args(): capture_path = "res://captures/night.png"
        if "--sunset" in OS.get_cmdline_user_args(): capture_path = "res://captures/sunset.png"
        get_viewport().get_texture().get_image().save_png(capture_path)
        get_tree().quit()

func label(text_value: String, font_size: int, color: Color) -> Label:
    var item := Label.new()
    item.text = text_value
    item.add_theme_font_size_override("font_size", font_size)
    item.add_theme_color_override("font_color", color)
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return item

func pointer_over_panel() -> bool:
    var point := get_viewport().get_mouse_position()
    for panel in ui_panels:
        if panel.is_visible_in_tree() and panel.get_global_rect().has_point(point): return true
    return false

func panel_column(layer: CanvasLayer, location: Vector2, width: float, title: String) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.position = location
    panel.custom_minimum_size.x = width
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.10, 0.14, 0.12, 0.96)
    style.border_color = Color("8f7d53")
    style.set_border_width_all(1)
    style.set_content_margin_all(14)
    style.set_corner_radius_all(4)
    panel.add_theme_stylebox_override("panel", style)
    layer.add_child(panel)
    ui_panels.append(panel)
    var frame := VBoxContainer.new()
    panel.add_child(frame)
    var toggle := Button.new()
    toggle.text = title + "  −"
    toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
    toggle.focus_mode = Control.FOCUS_NONE
    toggle.add_theme_font_size_override("font_size", 14)
    frame.add_child(toggle)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    frame.add_child(column)
    panel_states[title] = {"panel": panel, "body": column, "toggle": toggle}
    toggle.pressed.connect(func(): set_panel_collapsed(title, column.visible))
    var preferences := ConfigFile.new()
    if preferences.load("user://interface.cfg") == OK:
        if preferences.get_value("panels", title, false):
            column.hide()
            toggle.text = title + "  +"
    return column

func set_panel_collapsed(title: String, collapsed: bool) -> void:
    var state: Dictionary = panel_states[title]
    state.body.visible = not collapsed
    state.toggle.text = title + ("  +" if collapsed else "  −")
    state.panel.set_deferred("size", Vector2.ZERO)
    var preferences := ConfigFile.new()
    preferences.load("user://interface.cfg")
    preferences.set_value("panels", title, collapsed)
    if "--capture" not in OS.get_cmdline_user_args(): preferences.save("user://interface.cfg")

func game_button(column: BoxContainer, title: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = title
    button.add_theme_font_size_override("font_size", 14)
    button.pressed.connect(action)
    button.focus_mode = Control.FOCUS_NONE
    column.add_child(button)
    return button

func show_intro() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    var shade := ColorRect.new()
    shade.color = Color(0.025, 0.04, 0.035, 0.72)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(shade)
    intro_panel = PanelContainer.new()
    intro_panel.anchor_left = 0.5
    intro_panel.anchor_top = 0.5
    intro_panel.anchor_right = 0.5
    intro_panel.anchor_bottom = 0.5
    intro_panel.offset_left = -280
    intro_panel.offset_top = -190
    intro_panel.offset_right = 280
    intro_panel.offset_bottom = 190
    var style := StyleBoxFlat.new()
    style.bg_color = Color("17231d")
    style.border_color = Color("b79b62")
    style.set_border_width_all(2)
    style.set_content_margin_all(26)
    style.set_corner_radius_all(8)
    intro_panel.add_theme_stylebox_override("panel", style)
    layer.add_child(intro_panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    intro_panel.add_child(content)
    content.add_child(label("FIRST STEPS", 13, Color("c9ad70")))
    content.add_child(label("Build a settlement that can endure", 25, Color("f0e6ce")))
    intro_copy = label("", 16, Color("d5d9bd"))
    intro_copy.custom_minimum_size = Vector2(500, 105)
    intro_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(intro_copy)
    var actions := HBoxContainer.new()
    content.add_child(actions)
    var back := Button.new()
    back.text = "Back"
    back.focus_mode = Control.FOCUS_NONE
    back.pressed.connect(func(): intro_step = maxi(0, intro_step - 1); update_intro())
    actions.add_child(back)
    var next := Button.new()
    next.text = "Next"
    next.focus_mode = Control.FOCUS_NONE
    next.pressed.connect(func():
        if intro_step < 3:
            intro_step += 1
            update_intro()
        else:
            finish_intro())
    actions.add_child(next)
    var skip := Button.new()
    skip.text = "Skip guide"
    skip.focus_mode = Control.FOCUS_NONE
    skip.pressed.connect(finish_intro)
    actions.add_child(skip)
    update_intro()

func update_intro() -> void:
    if not is_instance_valid(intro_copy): return
    var steps := [
        "You begin with 30 adults, temporary shelter, and a small food reserve. Gathering is your only available job. Watch food and assign some adults to gathering before the reserve runs out.",
        "Open the technology tree from the Research button. Choose Toolmaking to unlock fishing, woodcutting, stoneworking, and shelter building. Planting is another early path toward steady food.",
        "Learn Shelter Building, then choose House in Buildings and click a clear hex to place it. Materials are paid up front; builders finish it over time. Planting unlocks fields, which need farmers to grow crops.",
        "Use Resume to let the world run, or Advance up to one season. Scroll to zoom, drag to move, and press Esc to close a screen or cancel placement. Keep food secure as you grow."
    ]
    intro_copy.text = "%d / %d\n\n%s" % [intro_step + 1, steps.size(), steps[intro_step]]

func finish_intro() -> void:
    if is_instance_valid(intro_panel): intro_panel.get_parent().queue_free()
    sim.has_seen_intro = true
    sim.save_game()

func resource_indicator(row: HBoxContainer, resource: String, width: float) -> VBoxContainer:
    var button := Button.new()
    button.name = resource.capitalize() + "Indicator"
    button.custom_minimum_size.x = width
    button.tooltip_text = "Click to view " + resource + " details."
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.7, 0.65, 0.4, 0.12)
    hover.set_corner_radius_all(4)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.pressed.connect(func(): resource_panel.open_resource(resource))
    row.add_child(button)
    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    button.add_child(column)
    return column

func make_top_bar(layer: CanvasLayer) -> void:
    var bar := PanelContainer.new()
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    bar.offset_bottom = 76
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.075, 0.115, 0.095, 0.98)
    style.border_color = Color("9e895b")
    style.border_width_bottom = 1
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    bar.add_theme_stylebox_override("panel", style)
    layer.add_child(bar)
    ui_panels.append(bar)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    bar.add_child(row)
    var identity := VBoxContainer.new()
    identity.custom_minimum_size.x = 150
    row.add_child(identity)
    civilization_title = label("FIRST SETTLEMENT", 11, Color("c5b286"))
    civilization_title.clip_text = true
    identity.add_child(civilization_title)
    top_date = label("", 16, Color("e5dfc9"))
    identity.add_child(top_date)
    day_clock = preload("res://scripts/day_clock.gd").new()
    row.add_child(day_clock)
    row.add_child(VSeparator.new())
    for resource in ["food", "wood", "stone"]:
        var column := resource_indicator(row, resource, 90)
        column.add_theme_constant_override("separation", 2)
        column.add_child(label(resource.to_upper(), 11, Color("a8b79f")))
        var amount := label("", 21, Color("eee1bf"))
        column.add_child(amount)
        resource_labels[resource] = amount
        if resource in ["wood", "stone"]:
            var rate := label("", 11, Color("b6cf9a"))
            rate.tooltip_text = "Collected per game day during the latest simulation interval, after storage limits. Building and equipment costs are separate."
            column.add_child(rate)
            resource_rate_labels[resource] = rate

    row.add_child(VSeparator.new())
    var storage := resource_indicator(row, "storage", 110)
    storage.add_child(label("STORAGE", 11, Color("a8b79f")))
    top_storage = label("", 18, Color("e5dfc9"))
    storage.add_child(top_storage)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)
    happiness_button = Button.new()
    happiness_button.custom_minimum_size.x = 160
    happiness_button.add_theme_font_size_override("font_size", 15)
    happiness_button.focus_mode = Control.FOCUS_NONE
    happiness_button.tooltip_text = "View food, ration, water, bedding, and living-condition influences."
    happiness_button.pressed.connect(func(): happiness_panel.show())
    row.add_child(happiness_button)
    research_button = Button.new()
    research_button.custom_minimum_size.x = 235
    research_button.add_theme_font_size_override("font_size", 14)
    research_button.focus_mode = Control.FOCUS_NONE
    research_button.tooltip_text = "Research progresses continuously. Open the technology tree to choose or queue a technology."
    research_button.pressed.connect(func(): research_screen.show())
    row.add_child(research_button)
    var multiplayer_button := Button.new()
    multiplayer_button.text = "World / Multiplayer"
    multiplayer_button.focus_mode = Control.FOCUS_NONE
    multiplayer_button.pressed.connect(func(): multiplayer_screen.show())
    row.add_child(multiplayer_button)
    var settings := Button.new()
    settings.text = "Settings"
    settings.custom_minimum_size.x = 95
    settings.focus_mode = Control.FOCUS_NONE
    settings.tooltip_text = "Audio, hex lines, camera, and display preferences."
    settings.pressed.connect(func(): settings_panel.show())
    row.add_child(settings)

func make_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var command := panel_column(layer, Vector2(20, 96), 360, "Command")
    var command_tabs := TabContainer.new()
    command_tabs.custom_minimum_size = Vector2(330, 500)
    command.add_child(command_tabs)
    var overview := VBoxContainer.new()
    overview.name = "Overview"
    overview.add_theme_constant_override("separation", 7)
    command_tabs.add_child(overview)
    var build_page := VBoxContainer.new()
    build_page.name = "Build"
    build_page.add_theme_constant_override("separation", 5)
    command_tabs.add_child(build_page)
    var people_page := VBoxContainer.new()
    people_page.name = "People"
    people_page.add_theme_constant_override("separation", 5)
    command_tabs.add_child(people_page)
    var explore_page := VBoxContainer.new()
    explore_page.name = "Explore"
    explore_page.add_theme_constant_override("separation", 7)
    command_tabs.add_child(explore_page)
    var military_page := VBoxContainer.new()
    military_page.name = "Military"
    military_page.add_theme_constant_override("separation", 7)
    command_tabs.add_child(military_page)
    overview.add_child(label("A beginning by the river", 21, Color("f0e6ce")))
    status_label = label("", 14, Color("d5d9bd"))
    overview.add_child(status_label)
    stock_label = label("", 14, Color("e5d6b8"))
    overview.add_child(stock_label)
    overview.add_child(HSeparator.new())
    worker_label = label("", 14, Color("e5d6b8"))
    overview.add_child(worker_label)
    game_button(overview, "First steps guide", func(): intro_step = 0; show_intro())

    var build_tabs := TabContainer.new()
    build_page.add_child(build_tabs)
    var groups := {
        "Housing": {"types": ["House"], "hint": "Permanent homes provide shelter and bedding."},
        "Resources": {"types": ["Storehouse", "Field"], "hint": "Store materials or grow crops with assigned farmers."},
        "Services": {"types": ["Well", "School"], "hint": "Improve water quality, training, and education."},
        "Military": {"types": ["Training Grounds", "Barracks", "Palisade", "Wall"], "hint": "Training grounds train soldiers; barracks house 12 each; palisades and Masonry walls strengthen defense."}
    }
    for category in groups:
        var page := VBoxContainer.new()
        page.name = category
        page.add_theme_constant_override("separation", 5)
        build_tabs.add_child(page)
        for kind in groups[category].types:
            var cost: Dictionary = sim.BUILDINGS[kind]
            build_buttons[kind] = game_button(page, "%s · %d wood / %d stone" % [kind, cost.wood, cost.stone], func():
                var blocked: String = sim.building_block(kind)
                if not blocked.is_empty():
                    feedback.text = blocked
                    refresh_game()
                    return
                build_choice = kind
                hex_grid.visible = true
                feedback.text = "Place %s on a clear hex in the starting zone." % kind)
        var hint := label(groups[category].hint, 12, Color("9fae99"))
        hint.custom_minimum_size.x = 300
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        page.add_child(hint)
    project_label = label("", 13, Color("c8d1bc"))
    project_label.custom_minimum_size.x = 300
    project_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    build_page.add_child(project_label)

    game_button(people_page, "Population & workforce priorities", func(): population_screen.show())
    people_page.add_child(HSeparator.new())
    people_page.add_child(label("Worker assignments", 16, Color("f0e6ce")))
    for job in sim.JOBS:
        var row := HBoxContainer.new()
        people_page.add_child(row)
        var title := label(job, 14, Color("c8d1bc"))
        title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(title)
        var spinner := SpinBox.new()
        spinner.min_value = 0
        spinner.max_value = sim.population
        spinner.step = 1
        spinner.custom_minimum_size.x = 76
        spinner.get_line_edit().focus_mode = Control.FOCUS_NONE
        spinner.value = sim.assignments[job]
        spinner.value_changed.connect(func(value):
            var was_diverting: bool = sim.emergency_food
            order("assign", [job, int(value)])
            if was_diverting and not sim.emergency_food:
                feedback.text = "Manual assignment applied. Food-shortage diversion turned off; re-enable its checkbox if needed."
            citizens.sync_people()
            sim.save_game()
            refresh_game())
        row.add_child(spinner)
        job_controls[job] = spinner
    emergency_food_toggle = CheckBox.new()
    emergency_food_toggle.text = "Food shortage: divert builders / quarry"
    emergency_food_toggle.tooltip_text = "Temporarily sends builders and quarry workers gathering when food is low. Manually increasing either job turns this response off."
    emergency_food_toggle.button_pressed = sim.emergency_food
    emergency_food_toggle.toggled.connect(func(value):
        order("policy", ["emergency_food", value])
        citizens.sync_people()
        sim.save_game()
        refresh_game())
    people_page.add_child(emergency_food_toggle)

    # TabContainer owns page visibility; scouting availability is handled by its controls.
    exploration_label = label("", 13, Color("c8d1bc"))
    exploration_label.custom_minimum_size = Vector2(300, 75)
    exploration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    explore_page.add_child(exploration_label)
    game_button(explore_page, "Choose destination on map", begin_scout_selection)
    scout_button = game_button(explore_page, "Send 3 settlers to scout", func():
        if not has_selected_land:
            begin_scout_selection()
            return
        dispatch_scouts(selected_land))
    explore_page.add_child(label("Click land to inspect · drag to move the map.\nUnknown land is hidden; old reports fade.", 12, Color("9fae99")))

    game_button(military_page, "Armies & commanders", func(): multiplayer_screen.open_warfare())
    military_page.add_child(label("Build training grounds and barracks from Build → Military.", 13, Color("9fae99")))

    var bottom := panel_column(layer, Vector2(20, 660), 620, "Time & events")
    var controls := HBoxContainer.new()
    bottom.add_child(controls)
    var play := Button.new()
    play_button = play
    play.text = "Resume"
    play.focus_mode = Control.FOCUS_NONE
    play.pressed.connect(func(): running = not running; play.text = "Pause" if running else "Resume")
    controls.add_child(play)
    solo_time_controls.append(play)
    var speed := OptionButton.new()
    speed.add_item("World clock")
    speed.add_item("Playtest: 1 day / second")
    speed.add_item("Playtest: 5 days / second")
    speed.item_selected.connect(func(index): play_speed = [0.0, 1.0, 5.0][index])
    controls.add_child(speed)
    solo_time_controls.append(speed)
    var clock := OptionButton.new()
    clock.add_item("1 real day / season")
    clock.add_item("1 real day / year")
    clock.selected = 1 if sim.days_per_real_day == 360 else 0
    clock.item_selected.connect(func(index): sim.days_per_real_day = 90.0 if index == 0 else 360.0)
    controls.add_child(clock)
    solo_time_controls.append(clock)
    var restart := Button.new()
    restart.text = "New settlement"
    restart.focus_mode = Control.FOCUS_NONE
    restart.pressed.connect(func():
        var dialog := ConfirmationDialog.new()
        dialog.title = "Start a new settlement?"
        dialog.dialog_text = "Replace the local save with a fresh gathering-only settlement?"
        dialog.confirmed.connect(func():
            sim = preload("res://scripts/simulation.gd").new()
            if "--guest-profile" in OS.get_cmdline_user_args(): sim.save_path = "user://guest_settlement.json"
            sim.days_per_real_day = 90.0 if clock.selected == 0 else 360.0
            sim.tick(0)
            running = false
            play_button.text = "Resume"
            build_choice = ""
            refresh_hex_grid()
            visual_revision = -1
            if is_instance_valid(exploration): exploration.invalidate()
            research_screen.selected = "Toolmaking"
            refresh_game()
            sim.save_game())
        dialog.canceled.connect(func(): dialog.queue_free())
        dialog.confirmed.connect(func(): dialog.queue_free())
        add_child(dialog)
        dialog.popup_centered())
    controls.add_child(restart)
    solo_time_controls.append(restart)
    game_button(bottom, "Advance up to one season · stops at a food crisis", func():
        if is_instance_valid(session) and session.connecting:
            feedback.text = "Wait for the shared world to connect."
            return
        if is_instance_valid(session) and session.active:
            feedback.text = session.vote_fast_forward()
        else:
            sim.advance(90, true)
            refresh_game()
            sim.save_game())
    feedback = label("Gather food first. Toolmaking opens professions; Shelter Building unlocks construction.", 13, Color("d5c394"))
    feedback.custom_minimum_size.x = 650
    feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback.max_lines_visible = 2
    bottom.add_child(feedback)
    event_label = label("", 13, Color("c8d1bc"))
    event_label.custom_minimum_size.x = 650
    event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_label.max_lines_visible = 2
    bottom.add_child(event_label)
    bottom.add_child(label("Local prototype · pause and speed controls are for playtesting.\nScroll / pinch zoom · drag map · Q/E orbit · Tab collapse panels · Esc cancel", 12, Color("9fae99")))
    make_top_bar(layer)
    var research_layer := CanvasLayer.new()
    research_layer.layer = 10
    add_child(research_layer)
    research_screen = preload("res://scripts/research_screen.gd").new()
    research_layer.add_child(research_screen)
    research_screen.setup(self)
    population_screen = preload("res://scripts/population_screen.gd").new()
    research_layer.add_child(population_screen)
    population_screen.setup(self)
    resource_panel = preload("res://scripts/resource_panel.gd").new()
    research_layer.add_child(resource_panel)
    resource_panel.setup(self)
    object_panel = preload("res://scripts/object_panel.gd").new()
    research_layer.add_child(object_panel)
    object_panel.setup(self)
    happiness_panel = preload("res://scripts/happiness_panel.gd").new()
    research_layer.add_child(happiness_panel)
    happiness_panel.setup(self)
    settings_panel = preload("res://scripts/settings_panel.gd").new()
    research_layer.add_child(settings_panel)
    settings_panel.setup(self)


func refresh_game() -> void:
    if not is_instance_valid(status_label): return
    resource_deposits.refresh(self)
    var online: bool = is_instance_valid(session) and (session.active or session.connecting)
    civilization_title.text = str(session.cached_own.get("civilization_name", "SHARED WORLD")) if online else "FIRST SETTLEMENT"
    for control in solo_time_controls:
        if control is BaseButton: control.disabled = online
        control.tooltip_text = "Shared worlds use the clock selected at creation. Fast-forward requires everyone’s agreement." if online else ""
    play_button.text = "World running" if online else ("Pause" if running else "Resume")
    happiness_button.text = "HAPPINESS\n%.0f / 100 · influences" % sim.happiness
    happiness_button.add_theme_color_override("font_color", Color("d99580") if sim.happiness < 40 else Color("dec58f") if sim.happiness < 60 else Color("b6cf9a"))
    for resource in resource_labels: resource_labels[resource].text = "%.1f" % sim.resources[resource]
    for resource in resource_rate_labels:
        resource_rate_labels[resource].text = "+%.2f / day" % float(sim.material_production.get(resource, 0.0))
    top_storage.text = "%.0f / %.0f" % [sim.resources.food + sim.resources.wood + sim.resources.stone, sim.capacity()]
    if is_instance_valid(resource_panel) and resource_panel.visible: resource_panel.refresh()
    if is_instance_valid(object_panel) and object_panel.visible: object_panel.refresh()
    if is_instance_valid(happiness_panel) and happiness_panel.visible: happiness_panel.refresh()
    update_season_visuals()
    day_clock.refresh(sim)
    var season: String = ["Spring", "Summer", "Autumn", "Winter"][int(sim.day / 90) % 4]
    top_date.text = "%s · Year %d" % [season, int(sim.day / 360) + 1]
    top_date.tooltip_text = sim.season_description()
    status_label.text = "%s · Year %d · Day %d\n%s" % [season, int(sim.day / 360) + 1, int(sim.day) % 90 + 1, " · ".join(sim.conditions)]
    stock_label.text = "Food use: %.2f / day · Production: %.2f / day\nHousing %d / %d" % [sim.food_need(), sim.food_ledger.production, sim.population, sim.housing()]
    worker_label.text = "%d settlers · %d adults · %d assigned" % [sim.population, sim.adults(), sim.workers_used()]
    emergency_food_toggle.set_pressed_no_signal(sim.emergency_food)
    var effective_work: Dictionary = sim.effective_assignments()
    var diverted: int = int(sim.assignments.Construction) - int(effective_work.Construction) + int(sim.assignments.Quarrying) - int(effective_work.Quarrying)
    if diverted > 0: worker_label.text += "\nFood response: %d builders / quarry gathering" % diverted
    for job in job_controls:
        job_controls[job].set_block_signals(true)
        job_controls[job].max_value = sim.workforce_capacity() - sim.workers_used() + sim.assignments[job]
        job_controls[job].set_value_no_signal(sim.assignments[job])
        job_controls[job].set_block_signals(false)
        job_controls[job].editable = sim.job_unlocked(job)
        job_controls[job].tooltip_text = "Requires " + sim.JOB_TECH[job] if not sim.job_unlocked(job) else "Assign working-age adults; manual changes disable percentage automation."
        # Blocking signals also suppresses SpinBox's internal limit-state refresh.
        # Refresh it after syncing, even when the displayed count did not change.
        job_controls[job].changed.emit()
    for kind in build_buttons:
        var blocked: String = sim.building_block(kind)
        build_buttons[kind].disabled = not blocked.is_empty()
        build_buttons[kind].tooltip_text = blocked
    research_button.text = "RESEARCH · %.2f / season\n%s · %.0f%%" % [1.25 if sim.completed("School") > 0 else 1.0, sim.research if not sim.research.is_empty() else "Choose a technology", 100 * sim.research_progress / sim.TECHNOLOGIES.get(sim.research, 1)]
    if is_instance_valid(exploration_label):
        exploration_label.text = sim.land_report(selected_land) if has_selected_land else "Choose destination on map, then click the land you want surveyed."
        var scout_block: String = sim.scouting_block(selected_land) if has_selected_land else "Choose a destination on the map first."
        scout_button.disabled = not scout_block.is_empty() or (is_instance_valid(session) and session.connecting)
        scout_button.text = "Scout (%.0f, %.0f) · %d settlers · %d food" % [selected_land.x, selected_land.y, 3, sim.scout_food_cost(selected_land)] if has_selected_land else "Select a destination first"
        scout_button.tooltip_text = scout_block if not scout_block.is_empty() else "Send another party. Food is packed for the expected round trip; settlers remain unavailable until they return."
    var projects := PackedStringArray()
    for b in sim.buildings:
        if b.progress < 1: projects.append("%s: %.0f%%" % [b.kind, b.progress * 100])
    project_label.text = "\n".join(projects) if projects.size() else "No construction in progress."
    event_label.text = "\n".join(sim.events.slice(0, 2))
    event_label.tooltip_text = event_label.text
    if is_instance_valid(research_screen) and research_screen.visible: research_screen.refresh()
    if is_instance_valid(population_screen) and population_screen.visible: population_screen.refresh()
    if visual_revision != sim.revision:
        visual_revision = sim.revision
        rebuild_buildings()

func place_building(screen: Vector2) -> void:
    var origin := camera.project_ray_origin(screen)
    var direction := camera.project_ray_normal(screen)
    var distance := (0.5 - origin.y) / direction.y
    var point := origin + direction * distance
    for i in range(6):
        distance = (surface_height(point.x, point.z) - origin.y) / direction.y
        point = origin + direction * distance
    var nearest := Vector2i.ZERO
    var best := INF
    for q in range(-6, 7):
        for r in range(-6, 7):
            var center := Vector2(3.0 * q, sqrt(3.0) * 2 * (r + q * 0.5))
            var length := center.distance_squared_to(Vector2(point.x, point.z))
            if length < best:
                best = length
                nearest = Vector2i(q, r)
    var error: String = order("build", [build_choice, int(nearest.x), int(nearest.y)])
    feedback.text = error if not error.is_empty() else "%s commissioned. Assign construction workers to build it." % build_choice
    if error.is_empty() or error == "Order sent to the host.":
        build_choice = ""
        refresh_hex_grid()
        sim.save_game()
    refresh_game()

func rebuild_buildings() -> void:
    for child in building_nodes.get_children():
        building_nodes.remove_child(child)
        child.queue_free()
    for b in sim.buildings:
        var center := Vector2(3.0 * b.q, sqrt(3.0) * 2 * (b.r + b.q * 0.5))
        if b.progress >= 1 and b.kind in ["House", "Storehouse", "School", "Barracks"]:
            var home := house(center.x, center.y, 0.15, 0.85)
            home.reparent(building_nodes)
            inspectable(home, {"kind": b.kind, "q": b.q, "r": b.r})
            if b.kind == "Barracks":
                var banner := Node3D.new()
                building_nodes.add_child(banner)
                banner.position = pos(center.x + 1.2, center.y, 0.05)
                beam(banner, Vector3.ZERO, Vector3(0, 2.6, 0), 0.04, mats.wood)
                box(banner, Vector3(0.34, 2.3, 0), Vector3(0.65, 0.4, 0.035), mats.cloth)
                inspectable(banner, {"kind": b.kind, "q": b.q, "r": b.r})
        else:
            var site := Node3D.new()
            building_nodes.add_child(site)
            site.position = pos(center.x, center.y, 0.04)
            inspectable(site, {"kind": b.kind, "q": b.q, "r": b.r})
            if b.progress < 1:
                for xx in [-1.2, 1.2]:
                    for zz in [-1.2, 1.2]:
                        beam(site, Vector3(xx, 0, zz), Vector3(xx, 0.8, zz), 0.05, mats.wood)
                box(site, Vector3(0, 0.1, 0), Vector3(2.4, 0.2, 2.4), mats.stone)
            elif b.kind == "Training Grounds":
                box(site, Vector3(0, 0.03, 0), Vector3(2.8, 0.06, 2.8), mats.soil)
                for xx in [-0.8, 0.0, 0.8]:
                    beam(site, Vector3(xx, 0, -0.7), Vector3(xx, 1.2, -0.7), 0.04, mats.wood)
                    cylinder(site, Vector3(xx, 1.0, -0.7), 0.23, 0.23, 0.07, mats.thatch).rotation_degrees.x = 90
            elif b.kind == "Palisade":
                for i in range(20):
                    var angle := i * TAU / 20.0
                    cylinder(site, Vector3(cos(angle) * 1.35, 0.75, sin(angle) * 1.35), 0.11, 0.02, 1.5, mats.wood, 6)
            elif b.kind == "Wall":
                stone_wall(site)
            elif b.kind == "Well":
                cylinder(site, Vector3(0, 0.45, 0), 0.7, 0.7, 0.9, mats.stone)
                cylinder(site, Vector3(0, 0.91, 0), 0.46, 0.46, 0.02, mats.dark)
                beam(site, Vector3(-0.9, 0, 0), Vector3(-0.9, 1.9, 0), 0.07, mats.wood)
                beam(site, Vector3(0.9, 0, 0), Vector3(0.9, 1.9, 0), 0.07, mats.wood)
                beam(site, Vector3(-0.9, 1.9, 0), Vector3(0.9, 1.9, 0), 0.07, mats.wood)
            elif b.kind == "Field":
                box(site, Vector3(0, 0, 0), Vector3(2.7, 0.03, 2.7), mats.soil)
                for row in range(6):
                    for col in range(6):
                        cylinder(site, Vector3(-1.1 + col * 0.44, 0.13, -1.1 + row * 0.44), 0.035, 0.015, 0.26, mats.reed, 5)

func stone_wall(parent: Node3D) -> void:
    # A fortified section occupies one building hex, with towers and battlements.
    box(parent, Vector3(0, 0.8, 0), Vector3(2.9, 1.6, 0.55), mats.stone)
    for side in [-1.3, 1.3]:
        box(parent, Vector3(side, 1.0, 0), Vector3(0.55, 2.0, 0.9), mats.stone)
        for z in [-0.32, 0.32]:
            box(parent, Vector3(side, 2.13, z), Vector3(0.55, 0.26, 0.22), mats.stone)
    for i in range(5):
        box(parent, Vector3(-1.0 + i * 0.5, 1.75, 0), Vector3(0.26, 0.3, 0.55), mats.stone)
    for y in [0.4, 0.8, 1.2]:
        box(parent, Vector3(0, y, 0.281), Vector3(2.35, 0.025, 0.012), mats.dark)
        box(parent, Vector3(0, y, -0.281), Vector3(2.35, 0.025, 0.012), mats.dark)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if is_instance_valid(session): session.persist()
        sim.save_game()
        get_tree().quit()

func order(action: String, args: Array = []) -> String:
    if is_instance_valid(session): return session.command(action, args)
    return "The game is still loading."

func configure_world_map() -> void:
    var next_origin := Vector2(sim.world_origin[0], sim.world_origin[1])
    if next_origin == region_origin and bool(sim.shared_region) == region_shared: return
    region_origin = next_origin
    object_panel.hide()
    region_shared = sim.shared_region
    has_selected_land = false
    choosing_scout_destination = false
    for node in scenery_nodes:
        remove_child(node)
        node.queue_free()
    scenery_nodes.clear()
    var start := get_child_count()
    rng.seed = 72419
    make_land()
    make_river()
    make_paths()
    make_village()
    make_forest()
    var resources_start := get_child_count()
    make_rocks()
    make_reeds()
    for i in range(resources_start, get_child_count()): get_child(i).set_meta("explorable", true)
    for i in range(start, get_child_count()): scenery_nodes.append(get_child(i))
    resource_deposits.rebuild(self)
    for child in hex_grid.get_children():
        hex_grid.remove_child(child)
        child.queue_free()
    remove_child(hex_grid)
    make_hex_grid()
    refresh_hex_grid()
    exploration.replace_land()
    season_seen = -1
    if is_instance_valid(world_entities): world_entities.invalidate()
    reset_camera()

func update_season_visuals() -> void:
    var season := int(sim.day / 90) % 4
    if season == season_seen: return
    season_seen = season
    mats.grass.set_shader_parameter("season", season)
    if is_instance_valid(water_material): water_material.set_shader_parameter("season", season)
    ForestTree.set_season(season)
    mats.thatch.albedo_color = Color("b8b5ad") if season == 3 else Color("92764f")
    update_daylight()
    if is_instance_valid(exploration): exploration.redraw()

func make_hearth() -> void:
    var root := Node3D.new()
    root.position = pos(-3, 1.5)
    add_child(root)
    inspectable(root, {"kind": "Campfire"})
    var glow := StandardMaterial3D.new()
    glow.albedo_color = Color("ec9b40")
    glow.emission_enabled = true
    glow.emission = Color("ff9b35")
    glow.emission_energy_multiplier = 2.0
    hearth_flame = sphere(root, Vector3(0, 0.4, 0), Vector3(0.22, 0.36, 0.22), glow)
    hearth_light = OmniLight3D.new()
    hearth_light.position = Vector3(0, 1.1, 0)
    hearth_light.light_color = Color("ffb16a")
    hearth_light.omni_range = 7
    root.add_child(hearth_light)

func update_daylight() -> void:
    if not is_instance_valid(sunlight): return
    var strength: float = sim.daylight_strength()
    var hour: float = sim.day_phase() * 24
    var hours: Vector2 = sim.daylight_hours()
    var progress := clampf((hour - hours.x) / (hours.y - hours.x), 0, 1)
    var altitude := sin(progress * PI)
    var season := int(sim.day / 90) % 4
    var noon_color: Color = [Color("fff0d5"), Color("fff2cc"), Color("ffd3a0"), Color("cdddeb")][season]
    sunlight.light_color = Color("ffab72").lerp(noon_color, smoothstep(0, 0.55, altitude))
    sunlight.light_energy = strength * [0.85, 0.95, 0.8, 0.65][season]
    sunlight.rotation_degrees = Vector3(-maxf(8, altitude * (38 if season == 3 else 62)), lerpf(-105, 75, progress), 0)
    moonlight.light_energy = (1 - strength) * 0.26
    sky_environment.background_color = Color("17263f").lerp(Color("cc9780").lerp(Color("9eafa1"), altitude), strength)
    sky_environment.ambient_light_color = Color("748db7").lerp(Color("b5c6cc"), strength)
    sky_environment.ambient_light_energy = lerpf(0.22, 0.48, strength)
    if is_instance_valid(hearth_light):
        var flicker := 1.0 + sin(Time.get_ticks_msec() * 0.009) * 0.08
        hearth_light.light_energy = lerpf(1.8, 0.25, strength) * flicker
        hearth_flame.scale.y = flicker
