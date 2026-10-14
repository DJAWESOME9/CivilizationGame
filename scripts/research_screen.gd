extends Control

# Columns are prerequisite depth; rows keep related subjects together.
const POSITIONS = {
    "Arrow Slits": Vector2(4, 7),
    "Basketry": Vector2(0, 0), "Hunting": Vector2(1, 0), "Archery": Vector2(3, 0),
    "Planting": Vector2(0, 1), "Preservation": Vector2(1, 1), "Crop Rotation": Vector2(2, 1),
    "Toolmaking": Vector2(0, 2), "Woodcutting": Vector2(1, 2), "Forestry": Vector2(2, 2),
    "Stoneworking": Vector2(1, 3), "Carpentry": Vector2(2, 3), "Joinery": Vector2(3, 3),
    "Shelter Building": Vector2(1, 4), "Storage": Vector2(2, 4), "Pottery": Vector2(3, 4), "Masonry": Vector2(3, 2),
    "Sanitation": Vector2(2, 5), "Waterworks": Vector2(3, 5),
    "Scouting": Vector2(0, 6), "Fishing": Vector2(1, 6), "Boatbuilding": Vector2(3, 6), "River Navigation": Vector2(4, 6),
    "Community Organization": Vector2(2, 7), "Military Organization": Vector2(3, 7),
    "Education": Vector2(3, 8), "Writing": Vector2(4, 8)
}
const SUBJECTS = ["FOOD & HUNTING", "CROPS & PRESERVATION", "TOOLS & WOODLAND", "CRAFTS & WORKSHOPS", "HOUSING & STORAGE", "WATER & HEALTH", "EXPLORATION & RIVERS", "GOVERNMENT & MILITARY", "EDUCATION & WRITING"]
const TITLES = {"Arrow Slits": "FORTIFIED ARCHERY", "Joinery": "TIMBER WORKSHOPS", "Pottery": "CERAMIC STORAGE", "Boatbuilding": "RIVER CROSSINGS", "River Navigation": "LONG EXPEDITIONS", "Archery": "RANGED WARFARE", "Military Organization": "MILITARY TRAINING", "Writing": "RECORDED KNOWLEDGE","Community Organization": "LOCAL GOVERNMENT","Scouting": "EXPLORATION","Basketry": "WOVEN CARRIERS", "Planting": "CULTIVATION", "Toolmaking": "EARLY TOOLS", "Hunting": "TRACKING", "Fishing": "RIVER FOOD", "Shelter Building": "SETTLEMENT", "Stoneworking": "EXTRACTION", "Woodcutting": "TIMBER", "Preservation": "FOOD STORAGE", "Storage": "SUPPLY NETWORK", "Sanitation": "PUBLIC HEALTH", "Forestry": "REPLANTING", "Crop Rotation": "FERTILITY", "Carpentry": "CRAFTSMANSHIP", "Waterworks": "IRRIGATION", "Masonry": "STONE BUILDING", "Education": "THE NEXT GENERATION"}

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
    text_label("Scroll to explore · gold: requires · blue: unlocks", 13, Color("96ac93"), Vector2(650, 70))
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
    tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    add_child(tree_scroll)
    tree_content = Control.new()
    tree_content.custom_minimum_size = Vector2(1830, 1320)
    tree_content.mouse_filter = Control.MOUSE_FILTER_PASS
    tree_scroll.add_child(tree_content)
    tree_content.add_child(links)
    for i in range(5):
        var heading := text_label(["FOUNDATIONS", "FIRST ADVANCES", "DEVELOPMENT", "SPECIALIZATION", "LATER ADVANCES"][i], 12, Color("baa674"), Vector2(230 + i * 320, 8))
        heading.reparent(tree_content, false)
    for i in range(SUBJECTS.size()):
        var subject := text_label(SUBJECTS[i], 11, Color("96ac93"), Vector2(10, 62 + i * 140))
        subject.reparent(tree_content, false)
    for tech in POSITIONS:
        var card := Button.new()
        card.position = Vector2(230 + POSITIONS[tech].x * 320, 42 + POSITIONS[tech].y * 140)
        card.size = Vector2(215, 104)
        card.focus_mode = Control.FOCUS_NONE
        card.alignment = HORIZONTAL_ALIGNMENT_LEFT
        card.add_theme_font_size_override("font_size", 17)
        card.pressed.connect(func(): selected = tech; result.text = ""; refresh())
        tree_content.add_child(card)
        cards[tech] = card
        var icon := Sprite2D.new()
        icon.texture = load("res://assets/technology/" + ("shelter_building" if tech == "Community Organization" else tech.to_lower().replace(" ", "_")) + ".svg")
        icon.position = Vector2(13, 16)
        icon.centered = false
        icon.scale = Vector2(0.5, 0.5)
        card.add_child(icon)
        var title: Label = world.label(tech, 12 if tech.length() > 18 else 16, Color("e9dfc6"))
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
        var cost_label: Label = world.label("Available from start" if tech == "Scouting" else "%.0f research points" % world.sim.TECHNOLOGIES[tech], 11, Color("a6b599"))
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
            refresh()
            tree_scroll.ensure_control_visible.call_deferred(cards[selected]))
    hide()
    refresh()

func _input(event: InputEvent) -> void:
    if not visible or not is_instance_valid(tree_scroll): return
    if not tree_scroll.get_global_rect().has_point(get_global_mouse_position()): return
    if event is InputEventPanGesture:
        tree_scroll.scroll_horizontal += roundi(event.delta.x * 30)
        tree_scroll.scroll_vertical += roundi(event.delta.y * 30)
        get_viewport().set_input_as_handled()
    if event is InputEventMouseButton and event.pressed:
        var direction := 0
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]: direction = -1
        if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]: direction = 1
        if direction != 0:
            var amount := roundi(direction * 70 * (event.factor if event.factor > 0 else 1.0))
            if event.shift_pressed or event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
                tree_scroll.scroll_horizontal += amount
            else:
                tree_scroll.scroll_vertical += amount
            get_viewport().set_input_as_handled()

func refresh() -> void:
    var sim = world.sim
    var current: String = sim.research if not sim.research.is_empty() else "None selected"
    var current_cost: float = sim.TECHNOLOGIES.get(sim.research, 1.0)
    var rate_per_day: float = sim.research_points_per_day()
    summary.text = "Researching: %s · %.0f%% · %.2f research points / day" % [current, 100 * sim.research_progress / current_cost, rate_per_day]
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
        cards[tech].tooltip_text = sim.TECH_DETAILS[tech] + "\nRequires all: " + (", ".join(sim.PREREQUISITES[tech]) if not sim.PREREQUISITES[tech].is_empty() else "None") + "\n" + sim.research_block(tech)
        var card_style := style(color, border)
        card_style.set_border_width_all(3 if tech == selected else 2 if tech in sim.technologies or tech == sim.queued_research or tech == sim.research else 1)
        cards[tech].add_theme_stylebox_override("normal", card_style)
        cards[tech].add_theme_stylebox_override("hover", style(color.lightened(0.12), Color("eee0a7")))
        cards[tech].add_theme_stylebox_override("pressed", style(color.lightened(0.07), Color("eee0a7")))
        cards[tech].add_theme_color_override("font_color", Color("eee4cb") if state != "LOCKED" else Color("a4b1a5"))
    var prerequisites: String = ", ".join(sim.PREREQUISITES[selected])
    var blocked: String = sim.research_block(selected)
    detail.text = "%s · %s · %.0f research points\n%s\nRequires all: %s%s" % [selected, states[selected].text, sim.TECHNOLOGIES[selected], sim.TECH_DETAILS[selected], prerequisites if not prerequisites.is_empty() else "None", " · " + blocked if not blocked.is_empty() else ""]
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

func refresh_connections() -> void:
    # Show a local dependency view, with one independent arrow per relationship.
    # Long routes stay in the empty row gutters instead of crossing intervening cards.
    var layout: Array = [selected]
    for tech in cards: layout.append([tech, cards[tech].position, cards[tech].size])
    var next_layout := str(layout)
    if next_layout == connection_layout: return
    connection_layout = next_layout
    for child in links.get_children():
        links.remove_child(child)
        child.queue_free()
    connection_nodes.clear()
    var route_index := 0
    for tech in cards:
        for source in world.sim.PREREQUISITES[tech]:
            if tech != selected and source != selected: continue
            var parent: Button = cards[source]
            var target: Button = cards[tech]
            var incoming: Array = world.sim.PREREQUISITES[tech]
            var offset := (incoming.find(source) - (incoming.size() - 1) * 0.5) * 14.0
            var from := parent.position + Vector2(parent.size.x, parent.size.y * 0.5)
            var to := target.position + Vector2(0, target.size.y * 0.5 + offset)
            var exit_x := from.x + 18.0 + route_index * 5.0
            var enter_x := to.x - 18.0 - incoming.find(source) * 6.0
            var points := PackedVector2Array([from, Vector2(exit_x, from.y)])
            if target.position.x - parent.position.x > 330.0:
                var gutter_y := parent.position.y + parent.size.y + 10.0 + route_index * 3.0
                points.append(Vector2(exit_x, gutter_y))
                points.append(Vector2(enter_x, gutter_y))
                points.append(Vector2(enter_x, to.y))
            else:
                points.append(Vector2(exit_x, to.y))
            points.append(to)
            add_connection_path(points, source, [tech], true)
            var connection: Dictionary = connection_nodes[connection_nodes.size() - 1]
            var color := Color("efd08b") if tech == selected else Color("83c9ed")
            connection.line.default_color = color
            connection.line.width = 3.0
            connection.arrow.color = color
            route_index += 1
