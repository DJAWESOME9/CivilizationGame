extends SceneTree

var failures := 0

func _initialize() -> void:
    call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func run_checks() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    # Inject input through the viewport, including over the decorative HUD.
    var wheel := InputEventMouseButton.new()
    wheel.position = Vector2(50, 50)
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel.pressed = true
    wheel.factor = 0.5
    var initial: float = scene.camera_size
    root.push_input(wheel, true)
    check(scene.camera_size < initial, "Wheel zoom must work over the HUD")
    wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
    wheel.factor = 0.0
    var before: float = scene.camera_size
    root.push_input(wheel, true)
    check(scene.camera_size > before, "Zero-factor wheel events need a fallback")
    var pan := InputEventPanGesture.new()
    pan.position = Vector2(50, 50)
    pan.delta = Vector2(0, -2)
    before = scene.camera_size
    root.push_input(pan, true)
    check(scene.camera_size < before, "Trackpad scroll must zoom")
    var pinch := InputEventMagnifyGesture.new()
    pinch.factor = 1.2
    before = scene.camera_size
    root.push_input(pinch, true)
    check(scene.camera_size < before, "Pinch must zoom")
    scene.zoom_by(-100)
    check(is_equal_approx(scene.camera_size, 10), "Near zoom limit")
    scene.zoom_by(100)
    check(is_equal_approx(scene.camera_size, 185), "Far zoom limit")
    # 13x13 flat-top hexes have 456 shared edges and 102 boundary edges.
    var edges: Array = scene.hex_edges()
    check(edges.size() == 558, "Hex edges must be shared, not double drawn")
    for edge in edges:
        check(absf(edge[0].distance_to(edge[1]) - 2.0) < 0.001, "Hex edge length")
    # A point inside the first terrain triangle must match its plane.
    var x := 17.0
    var z := -12.0
    var expected: float = scene.ground_height(x, z) * 0.5 + scene.ground_height(x + 1, z) * 0.2 + scene.ground_height(x, z + 1) * 0.3
    check(absf(scene.surface_height(x + 0.2, z + 0.3) - expected) < 0.0001, "Overlay must use the rendered triangle surface")
    check(scene.grid_point(Vector2(10, 0)).y > -0.15, "Grid must remain above river waves")
    var trees: Array = []
    for child in scene.get_children():
        check(not child is Sprite3D, "Forest must not contain camera-facing image sprites")
        if child.has_method("set_live_sight"): trees.append(child)
    check(trees.size() > 100, "Forest must retain its trees")
    var oak = trees[0]
    var bounds: AABB = oak.canopy.mesh.get_aabb()
    check(bounds.size.x > 3 and bounds.size.y > 2 and bounds.size.z > 3, "Canopies need volume in all three dimensions")
    check(oak.trunk.mesh.get_surface_count() == 1, "Trunk and limbs should be baked into one mesh")
    check(oak.trunk.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Tree meshes must cast shadows")
    check(absf(oak.position.y - scene.surface_height(oak.position.x, oak.position.z)) < 0.001, "Tree roots must meet the terrain")
    oak.set_live_sight(false)
    check(is_equal_approx(oak.canopy.material_override.get_shader_parameter("sight_strength"), 0.62), "Remembered trees must be dimmed")
    oak.set_live_sight(true)
    check(is_equal_approx(oak.trunk.material_override.get_shader_parameter("sight_strength"), 1.0), "Live trees must restore normal lighting")
    scene.sim.day = 180
    scene.update_season_visuals()
    check(oak.canopy.material_override.get_shader_parameter("season") == 2, "Mesh foliage must receive autumn colors")
    scene.exploration.redraw()
    for plant in trees:
        var point := Vector2(plant.position.x, plant.position.z)
        check(plant.visible == scene.sim.explored.has(scene.sim.cell_key(point)), "Tree roots must follow exploration visibility")
    # Pick the rendered roof, not just the ground hex underneath it.
    scene.reset_camera()
    scene.sim.buildings = [
        {"kind": "House", "q": 0, "r": -2, "progress": 1.0, "growth": 0.0},
        {"kind": "Field", "q": -3, "r": -1, "progress": 1.0, "growth": 0.42},
        {"kind": "Well", "q": 0, "r": -3, "progress": 0.25, "growth": 0.0}]
    scene.rebuild_buildings()
    var home = scene.building_nodes.get_child(0)
    var screen: Vector2 = scene.camera.unproject_position(home.global_transform * Vector3(0, 2.5, 0))
    var picked: Dictionary = scene.pick_object(screen)
    check(picked.get("kind") == "House", "Clicking the roof must select its house")
    for title in scene.panel_states: scene.set_panel_collapsed(title, true)
    var click := InputEventMouseButton.new()
    click.position = screen
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    root.push_input(click, true)
    click.pressed = false
    root.push_input(click, true)
    check(scene.object_panel.visible and scene.object_panel.heading.text == "House", "A map click must open building details")
    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    root.push_input(escape, true)
    check(not scene.object_panel.visible, "Esc must dismiss object details")
    click.pressed = true
    root.push_input(click, true)
    var motion := InputEventMouseMotion.new()
    motion.position = screen + Vector2(20, 0)
    root.push_input(motion, true)
    click.pressed = false
    click.position = motion.position
    root.push_input(click, true)
    check(not scene.object_panel.visible, "Dragging must not open object details")
    scene.reset_camera()
    var field = scene.building_nodes.get_child(1)
    screen = scene.camera.unproject_position(field.global_position + Vector3(0, 0.1, 0))
    picked = scene.pick_object(screen)
    check(picked.get("kind") == "Field", "Clicking crops must select the field")
    scene.object_panel.open_object(picked)
    check(is_equal_approx(scene.object_panel.progress.value, 42), "Field details must show actual crop growth")
    scene.sim.buildings[1].growth = 0.65
    scene.object_panel.refresh()
    check(is_equal_approx(scene.object_panel.progress.value, 65), "Open details must refresh from current simulation data")
    scene.sim.day = 270
    scene.object_panel.refresh()
    check(scene.object_panel.status.text.begins_with("Dormant"), "Field details must explain winter dormancy")
    field.hide()
    check(scene.pick_object(screen).get("kind") != "Field", "Hidden objects must not be selectable")
    scene.object_panel.open_object({"kind": "Well", "q": 0, "r": -3})
    check(is_equal_approx(scene.object_panel.progress.value, 25), "Construction details must show actual progress")
    scene.sim.buildings[2].progress = 1
    scene.rebuild_buildings()
    scene.object_panel.refresh()
    check(not scene.object_panel.progress.visible and scene.object_panel.status.text.begins_with("Complete"), "Selection must survive rebuilding when construction finishes")
    print("Camera, grid, forest, and object inspection checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    quit(0 if failures == 0 else 1)
