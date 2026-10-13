extends Control

const POSITIONS = {
    "Scouting": Vector2(1130, 180),
    "Basketry": Vector2(50, 180), "Planting": Vector2(50, 320), "Toolmaking": Vector2(50, 460),
    "Hunting": Vector2(320, 180), "Fishing": Vector2(320, 320), "Shelter Building": Vector2(320, 460), "Stoneworking": Vector2(320, 600),
    "Woodcutting": Vector2(590, 180), "Preservation": Vector2(590, 320), "Storage": Vector2(590, 460), "Sanitation": Vector2(590, 600),
    "Forestry": Vector2(860, 180), "Crop Rotation": Vector2(860, 320), "Carpentry": Vector2(860, 460), "Waterworks": Vector2(860, 600),
    "Masonry": Vector2(1130, 460), "Education": Vector2(1130, 600)
}
const TITLES = {"Scouting": "EXPLORATION","Basketry": "WOVEN CARRIERS", "Planting": "CULTIVATION", "Toolmaking": "EARLY TOOLS", "Hunting": "TRACKING", "Fishing": "RIVER FOOD", "Shelter Building": "SETTLEMENT", "Stoneworking": "EXTRACTION", "Woodcutting": "TIMBER", "Preservation": "FOOD STORAGE", "Storage": "SUPPLY NETWORK", "Sanitation": "PUBLIC HEALTH", "Forestry": "REPLANTING", "Crop Rotation": "FERTILITY", "Carpentry": "CRAFTSMANSHIP", "Waterworks": "IRRIGATION", "Masonry": "STONE BUILDING", "Education": "THE NEXT GENERATION"}

var world: Node3D
var selected := "Planting"
var cards: Dictionary = {}
var states: Dictionary = {}
var labels: Dictionary = {}
var summary: Label
var queue_summary: Label
var learned_summary: Label
var detail: Label
var result: Label
var start: Button
var queue_button: Button
var links := Node2D.new()
var progress: ProgressBar
var connection_nodes: Dictionary = {}
var connection_layout := ""
var tree_scroll: ScrollContainer
var tree_content: Control

func style(color: Color, border: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(5)
    box.set_content_margin_all(14)
    return box

func text_label(value: String, size: int, color: Color, at: Vector2) -> Label:
    var item := Label.new()
    item.text = value
    item.position = at
    item.add_theme_font_size_override("font_size", size)
    item.add_theme_color_override("font_color", color)
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(item)
    return item

func button(value: String, at: Vector2, action: Callable) -> Button:
    var item := Button.new()
    item.text = value
    item.position = at
    item.custom_minimum_size = Vector2(185, 40)
    item.focus_mode = Control.FOCUS_NONE
    item.pressed.connect(action)
    add_child(item)
    return item

func setup(scene: Node3D) -> void:
    world = scene
    selected = world.sim.research if POSITIONS.has(world.sim.research) else "Toolmaking"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := Panel.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.add_theme_stylebox_override("panel", style(Color("101b18"), Color("685a3c")))
    add_child(background)
    var grain := TextureRect.new()
    var texture := NoiseTexture2D.new()
    var noise := FastNoiseLite.new()
    noise.frequency = 0.6
    texture.noise = noise
    texture.width = 512
    texture.height = 512
    grain.texture = texture
    grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grain.modulate = Color(0.2, 0.28, 0.21, 0.06)
    grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(grain)
    text_label("KNOWLEDGE OF THE ANCIENT WORLD", 13, Color("baa674"), Vector2(55, 32))
    text_label("The technology tree", 32, Color("f1e6cc"), Vector2(55, 54))
    text_label("Scroll sideways · wheel, trackpad or bottom scrollbar", 13, Color("96ac93"), Vector2(650, 70))
    button("Return to settlement · Esc", Vector2(1140, 45), func(): hide())
    summary = text_label("", 16, Color("c3d1bf"), Vector2(55, 107))
    queue_summary = text_label("", 16, Color("a9d8ff"), Vector2(650, 107))
    learned_summary = text_label("", 16, Color("b9e7a3"), Vector2(1120, 107))
    learned_summary.mouse_filter = Control.MOUSE_FILTER_PASS
    progress = ProgressBar.new()
    progress.position = Vector2(55, 145)
    progress.size = Vector2(1275, 7)
    progress.show_percentage = false
    add_child(progress)
    tree_scroll = ScrollContainer.new()
    tree_scroll.position = Vector2(40, 158)
    tree_scroll.size = Vector2(1360, 576)
    tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
    tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(tree_scroll)
    tree_content = Control.new()
    tree_content.custom_minimum_size = Vector2(1560, 560)
    tree_content.mouse_filter = Control.MOUSE_FILTER_PASS
    tree_scroll.add_child(tree_content)
    tree_content.add_child(links)
    for i in range(5):
        var heading := text_label(["FOUNDATIONS", "EARLY PROFESSIONS", "SETTLEMENT SYSTEMS", "SPECIALIZATION", "CIVIC DEVELOPMENT"][i], 11, Color("96ac93"), Vector2(10 + i * 320, 2))
        heading.reparent(tree_content, false)
    for tech in POSITIONS:
        var card := Button.new()
        card.position = POSITIONS[tech] - Vector2(40, 158)
        card.position.x = 10 + (POSITIONS[tech].x - 50) / 270.0 * 320
        card.size = Vector2(215, 104)
        card.focus_mode = Control.FOCUS_NONE
        card.alignment = HORIZONTAL_ALIGNMENT_LEFT
        card.add_theme_font_size_override("font_size", 17)
        card.pressed.connect(func(): selected = tech; result.text = ""; refresh())
        tree_content.add_child(card)
        cards[tech] = card
        var icon := Sprite2D.new()
        icon.texture = load("res://assets/technology/" + tech.to_lower().replace(" ", "_") + ".svg")
        icon.position = Vector2(13, 16)
        icon.centered = false
        icon.scale = Vector2(0.5, 0.5)
        card.add_child(icon)
        var title: Label = world.label(tech, 16, Color("e9dfc6"))
        title.position = Vector2(53, 14)
        card.add_child(title)
        var category: Label = world.label(TITLES[tech], 9, Color("9fad9b"))
        category.position = Vector2(53, 37)
        card.add_child(category)
        var state_label: Label = world.label("", 12, Color("b7c9a9"))
        state_label.position = Vector2(12, 73)
        state_label.size = Vector2(191, 24)
        state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(state_label)
        states[tech] = state_label
        labels[tech] = title
        var cost_label: Label = world.label("Available from start" if tech == "Scouting" else "%.2f cycles" % world.sim.TECHNOLOGIES[tech], 11, Color("a6b599"))
        cost_label.position = Vector2(14, 52)
        card.add_child(cost_label)
    var footer := Panel.new()
    footer.position = Vector2(40, 744)
    footer.size = Vector2(1360, 136)
    footer.add_theme_stylebox_override("panel", style(Color("192720"), Color("685a3c")))
    add_child(footer)
    detail = text_label("", 15, Color("e7dfc6"), Vector2(60, 760))
    detail.size.x = 820
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result = text_label("Select a technology to see requirements and choose a path.", 13, Color("b7b999"), Vector2(60, 839))
    start = button("Start research", Vector2(940, 775), func(): result.text = world.order("research", [selected, false]); world.sim.save_game(); refresh())
    queue_button = button("Queue next", Vector2(1150, 775), func(): result.text = world.order("research", [selected, true]); world.sim.save_game(); refresh())
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.orbiting = false
            refresh())
    hide()
    refresh()

func _input(event: InputEvent) -> void:
    if not visible or not is_instance_valid(tree_scroll): return
    if not tree_scroll.get_global_rect().has_point(get_global_mouse_position()): return
    if event is InputEventPanGesture:
        var movement: float = event.delta.x if absf(event.delta.x) >= absf(event.delta.y) else event.delta.y
        tree_scroll.scroll_horizontal += roundi(movement * 30)
        get_viewport().set_input_as_handled()
    if event is InputEventMouseButton and event.pressed:
        var direction := 0
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]: direction = -1
        if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]: direction = 1
        if direction != 0:
            tree_scroll.scroll_horizontal += roundi(direction * 70 * (event.factor if event.factor > 0 else 1.0))
            get_viewport().set_input_as_handled()

func refresh() -> void:
    var sim = world.sim
    var current: String = sim.research if not sim.research.is_empty() else "None selected"
    var current_cost: float = sim.TECHNOLOGIES.get(sim.research, 1.0)
    summary.text = "Researching: %s · %.0f%% · %.2f cycles / season" % [current, 100 * sim.research_progress / current_cost, 1.25 if sim.completed("School") > 0 else 1.0]
    queue_summary.text = "Queued next: %s" % (sim.queued_research if not sim.queued_research.is_empty() else "None")
    learned_summary.text = "Learned: %d / %d" % [sim.technologies.size(), cards.size()]
    learned_summary.tooltip_text = "Learned technologies: " + (", ".join(sim.technologies) if not sim.technologies.is_empty() else "None yet")
    progress.value = 100 * sim.research_progress / current_cost
    for tech in cards:
        var state := "AVAILABLE"
        var color := Color("22392e")
        var border := Color("65806b")
        var status_color := Color("bfceb9")
        var badge_color := Color("304637")
        if tech in sim.technologies:
            state = "✓  LEARNED"
            color = Color("345638")
            border = Color("a5d887")
            status_color = Color("e0f6ce")
            badge_color = Color("456e3d")
        elif tech == sim.research:
            state = "RESEARCHING · %.0f%%" % (100 * sim.research_progress / sim.TECHNOLOGIES[tech])
            color = Color("49402a")
            border = Color("d5b970")
            status_color = Color("ffe3a1")
            badge_color = Color("66532c")
        elif tech == sim.queued_research:
            state = "→  QUEUED NEXT"
            color = Color("233f59")
            border = Color("8ecbfa")
            status_color = Color("d8eeff")
            badge_color = Color("315f85")
        elif not sim.research_block(tech).is_empty():
            state = "LOCKED"
            color = Color("1a2723")
            border = Color("46544c")
            status_color = Color("8b9b90")
            badge_color = Color("22312b")
        if tech == selected: border = Color("eee0a7")
        states[tech].text = state
        states[tech].add_theme_color_override("font_color", status_color)
        var badge_style := style(badge_color, badge_color)
        badge_style.set_content_margin_all(0)
        states[tech].add_theme_stylebox_override("normal", badge_style)
        labels[tech].add_theme_color_override("font_color", Color("f0e5cb") if state != "LOCKED" else Color("a9b4a8"))
        cards[tech].tooltip_text = sim.TECH_DETAILS[tech] + "\n" + sim.research_block(tech)
        var card_style := style(color, border)
        card_style.set_border_width_all(3 if tech == selected else 2 if tech in sim.technologies or tech == sim.queued_research or tech == sim.research else 1)
        cards[tech].add_theme_stylebox_override("normal", card_style)
        cards[tech].add_theme_stylebox_override("hover", style(color.lightened(0.12), Color("eee0a7")))
        cards[tech].add_theme_stylebox_override("pressed", style(color.lightened(0.07), Color("eee0a7")))
        cards[tech].add_theme_color_override("font_color", Color("eee4cb") if state != "LOCKED" else Color("a4b1a5"))
    var prerequisites: String = ", ".join(sim.PREREQUISITES[selected])
    var blocked: String = sim.research_block(selected)
    detail.text = "%s · %s · %.2f cycles\n%s\n%s" % [selected, states[selected].text, sim.TECHNOLOGIES[selected], sim.TECH_DETAILS[selected], blocked if not blocked.is_empty() else ("Prerequisites: " + prerequisites if not prerequisites.is_empty() else "Foundational technology · no technology prerequisites.")]
    start.disabled = selected in sim.technologies or selected == sim.research or not blocked.is_empty()
    queue_button.disabled = selected in sim.technologies or selected == sim.research or selected == sim.queued_research or not sim.research_block(selected, true).is_empty() or sim.research.is_empty()
    start.text = "Learned" if selected in sim.technologies else "Researching" if selected == sim.research else "Start research"
    queue_button.text = "Queued next" if selected == sim.queued_research else "Queue next"
    refresh_connections()

func smooth_route(points: PackedVector2Array) -> PackedVector2Array:
    var rounded := PackedVector2Array([points[0]])
    for i in range(1, points.size() - 1):
        var corner := points[i]
        var radius := minf(12.0, minf(corner.distance_to(points[i - 1]), corner.distance_to(points[i + 1])) * 0.45)
        var enter := corner.move_toward(points[i - 1], radius)
        var leave := corner.move_toward(points[i + 1], radius)
        rounded.append(enter)
        for step in range(1, 13):
            var t := float(step) / 12.0
            rounded.append(enter * (1.0 - t) * (1.0 - t) + corner * 2.0 * (1.0 - t) * t + leave * t * t)
    rounded.append(points[points.size() - 1])
    return rounded

func add_connection_path(points: PackedVector2Array, source: String, targets: Array, arrow: bool = false) -> void:
    var line := Line2D.new()
    line.width = 2.2
    line.antialiased = true
    line.begin_cap_mode = Line2D.LINE_CAP_ROUND
    line.end_cap_mode = Line2D.LINE_CAP_ROUND
    line.joint_mode = Line2D.LINE_JOINT_ROUND
    line.points = smooth_route(points)
    links.add_child(line)
    var tip: Polygon2D = null
    if arrow:
        var to := points[points.size() - 1]
        tip = Polygon2D.new()
        tip.polygon = PackedVector2Array([to, to + Vector2(-7, -3.5), to + Vector2(-7, 3.5)])
        tip.antialiased = true
        links.add_child(tip)
    connection_nodes[connection_nodes.size()] = {"from": source, "targets": targets, "line": line, "arrow": tip}

func build_shared_routes(source: String, routes: Array) -> void:
    # Split collinear routes at every branch, then draw each shared segment once.
    # Keep networks from different prerequisites separate: a crossing is not a dependency.
    var vertices: Array[Vector2] = []
    for route in routes:
        for point in route.points:
            if point not in vertices: vertices.append(point)
    var edges: Dictionary = {}
    var adjacency: Dictionary = {}
    for route in routes:
        var points: PackedVector2Array = route.points
        for i in range(points.size() - 1):
            var a := points[i]
            var b := points[i + 1]
            if a.is_equal_approx(b): continue
            var cuts: Array[Vector2] = []
            for point in vertices:
                if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < 0.01:
                    cuts.append(point)
            cuts.sort_custom(func(left: Vector2, right: Vector2): return left.distance_squared_to(a) < right.distance_squared_to(a))
            for j in range(cuts.size() - 1):
                var first := vertices.find(cuts[j])
                var second := vertices.find(cuts[j + 1])
                var key := "%d:%d" % [mini(first, second), maxi(first, second)]
                if not edges.has(key):
                    edges[key] = {"a": first, "b": second, "targets": []}
                    if not adjacency.has(first): adjacency[first] = []
                    if not adjacency.has(second): adjacency[second] = []
                    adjacency[first].append(key)
                    adjacency[second].append(key)
                if route.target not in edges[key].targets: edges[key].targets.append(route.target)
    var visited: Dictionary = {}
    # Stop at forks; round uninterrupted runs through their intermediate corners.
    for vertex in adjacency:
        for key in adjacency[vertex]:
            if visited.has(key): continue
            if adjacency[vertex].size() == 2:
                var other_key: String = adjacency[vertex][0] if adjacency[vertex][1] == key else adjacency[vertex][1]
                if edges[other_key].targets == edges[key].targets: continue
            var chain := PackedVector2Array([vertices[vertex]])
            var current: int = vertex
            var edge_key: String = key
            var targets: Array = edges[key].targets
            while true:
                visited[edge_key] = true
                var edge: Dictionary = edges[edge_key]
                current = edge.b if edge.a == current else edge.a
                chain.append(vertices[current])
                if adjacency[current].size() != 2: break
                var next_key: String = adjacency[current][0] if adjacency[current][1] == edge_key else adjacency[current][1]
                if visited.has(next_key) or edges[next_key].targets != targets: break
                edge_key = next_key
            var has_arrow := false
            for route in routes:
                if chain[chain.size() - 1].is_equal_approx(route.points[route.points.size() - 1]): has_arrow = true
            # Chains may be traversed back toward the source; arrows still point into cards.
            for route in routes:
                if chain[0].is_equal_approx(route.points[route.points.size() - 1]):
                    chain.reverse()
                    has_arrow = true
                    break
            add_connection_path(chain, source, targets, has_arrow)

func refresh_connections() -> void:
    var sim = world.sim
    var layout: Array = []
    for tech in cards: layout.append([tech, cards[tech].position, cards[tech].size])
    var next_layout := str(layout)
    if next_layout != connection_layout:
        connection_layout = next_layout
        for child in links.get_children():
            links.remove_child(child)
            child.queue_free()
        connection_nodes.clear()
        var outgoing: Dictionary = {}
        for tech in cards: outgoing[tech] = []
        for tech in cards:
            for prerequisite in sim.PREREQUISITES[tech]: outgoing[prerequisite].append(tech)
        var lanes: Dictionary = {}
        for source in outgoing:
            var children: Array = outgoing[source]
            if children.is_empty(): continue
            var parent: Button = cards[source]
            var from := parent.position + Vector2(parent.size.x, parent.size.y * 0.5)
            # Separate trunks belonging to different technologies in the same column.
            var exit_x := from.x + 14.0 + roundi((parent.position.y - 22) / 140) * 5.0
            var band := roundi((parent.position.y - 22) / 140)
            for tech in children: band = mini(band, roundi((cards[tech].position.y - 22) / 140))
            var has_long_route := false
            for tech in children:
                if cards[tech].position.x - parent.position.x >= 350: has_long_route = true
            var route_y := 22.0 + band * 140.0 + 115.0
            if has_long_route:
                route_y += int(lanes.get(band, 0)) * 5.0
                lanes[band] = int(lanes.get(band, 0)) + 1
            var routes: Array = []
            for tech in children:
                var target: Button = cards[tech]
                var incoming: Array = sim.PREREQUISITES[tech]
                var in_index := incoming.find(source)
                var in_offset := (in_index - (incoming.size() - 1) * 0.5) * 10.0
                var to := target.position + Vector2(0, target.size.y * 0.5 + in_offset)
                var points := PackedVector2Array([from, Vector2(exit_x, from.y)])
                if target.position.x - parent.position.x < 300:
                    points.append(Vector2(exit_x, to.y))
                else:
                    var enter_x := to.x - 18.0 - in_index * 4.0
                    points.append(Vector2(exit_x, route_y))
                    points.append(Vector2(enter_x, route_y))
                    points.append(Vector2(enter_x, to.y))
                points.append(to)
                routes.append({"target": tech, "points": points})
            build_shared_routes(source, routes)
    for connection in connection_nodes.values():
        var active: bool = connection.from == selected or selected in connection.targets
        var color := Color("d6bb7d") if active else Color("9ab87d") if connection.from in sim.technologies else Color("4b6556")
        connection.line.default_color = color
        connection.line.z_index = 1 if active else 0
        if is_instance_valid(connection.arrow):
            connection.arrow.color = color
            connection.arrow.z_index = 2 if active else 0
