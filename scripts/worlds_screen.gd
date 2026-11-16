extends Control

const Simulation = preload("res://scripts/simulation.gd")
var world: Node3D
var cards: GridContainer
var title_input: LineEdit
var message: Label
var joined: Dictionary = {}
var joined_timer := 15.0
var selected := false

func root_path() -> String:
    return "user://guest_worlds" if "--guest-profile" in OS.get_cmdline_user_args() else "user://worlds"

func new_path(kind: String) -> String:
    DirAccess.make_dir_recursive_absolute(root_path())
    return root_path() + "/" + kind + "_" + Crypto.new().generate_random_bytes(16).hex_encode() + ".json"

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color("101b18")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var artwork := TextureRect.new()
    artwork.texture = preload("res://assets/branding/first-settlement.png")
    artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    artwork.modulate = Color(0.65, 0.72, 0.63, 0.3)
    artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(artwork)
    var gradient := Gradient.new()
    gradient.set_color(0, Color(0.035, 0.065, 0.055, 0.96))
    gradient.set_color(1, Color(0.035, 0.065, 0.055, 0.18))
    var veil_texture := GradientTexture2D.new()
    veil_texture.gradient = gradient
    veil_texture.fill_from = Vector2.ZERO
    veil_texture.fill_to = Vector2(1, 0.6)
    var veil := TextureRect.new()
    veil.texture = veil_texture
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(veil)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 40)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 16)
    margin.add_child(column)
    column.add_child(world.label("FIRST SETTLEMENT  /  CHRONICLES", 12, Color("c8ab73")))
    column.add_child(world.label("Your worlds", 30, Color("eee1bf")))
    column.add_child(world.label("Choose a civilization to continue, or begin a new world.", 16, Color("b7c9a9")))
    var row := HBoxContainer.new()
    column.add_child(row)
    title_input = LineEdit.new()
    title_input.placeholder_text = "New world name"
    title_input.max_length = 48
    title_input.custom_minimum_size.x = 280
    row.add_child(title_input)
    world.game_button(row, "Create solo world", create_solo)
    world.game_button(row, "Create multiplayer world", func():
        world.multiplayer_screen.resume_world.button_pressed = false
        world.multiplayer_screen.world_title.text = chosen_name()
        world.multiplayer_screen.pages.current_tab = 0
        world.multiplayer_screen.show())
    world.game_button(row, "Join a world", func():
        world.multiplayer_screen.pages.current_tab = 0
        world.multiplayer_screen.show())
    world.game_button(row, "Return to game", func():
        if selected or world.session.active: hide())
    message = world.label("", 14, Color("b7c9a9"))
    column.add_child(message)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    cards = GridContainer.new()
    cards.columns = 2
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("h_separation", 16)
    cards.add_theme_constant_override("v_separation", 16)
    scroll.add_child(cards)
    resized.connect(func(): cards.columns = 1 if size.x < 1000 else 2)
    var data = read_data(root_path() + "/joined.json")
    joined = data
    hide()

func read_data(path: String) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var data = JSON.parse_string(FileAccess.get_file_as_string(path))
    return data if data is Dictionary else {}

func chosen_name() -> String:
    var value := title_input.text.strip_edges()
    return "My world" if value.is_empty() else value

func open() -> void:
    if world.session.active: world.session.persist()
    else: world.sim.save_game()
    world.running = false
    message.text = ""
    refresh()
    show()
    move_to_front()

func refresh() -> void:
    for child in cards.get_children():
        cards.remove_child(child)
        child.queue_free()
    var guest := "guest_" if "--guest-profile" in OS.get_cmdline_user_args() else ""
    var paths: Array[String] = ["user://" + guest + "settlement.json", "user://" + guest + "multiplayer_world.json"]
    for file in DirAccess.get_files_at(root_path()):
        if file.begins_with("solo_") or file.begins_with("shared_"): paths.append(root_path() + "/" + file)
    for path in paths:
        var data := read_data(path)
        if data.is_empty(): continue
        if int(data.get("version", 0)) != 1:
            message.text = "Some saves use an unsupported format and were preserved."
            continue
        var shared := data.has("civilizations")
        if shared and not data.civilizations is Dictionary: continue
        var players: Array = data.civilizations.values() if shared else [{"ai": false}]
        make_card(data, players, "Hosted world" if shared else "Solo world", path)
    for data in joined.values():
        if data is Dictionary: make_card(data, data.get("players", []), "Joined world · last received date", "")
    if cards.get_child_count() == 0: message.text = "No saved worlds yet. Create your first world above."

func make_card(data: Dictionary, players: Array, role: String, path: String) -> void:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size.x = 420
    var style := StyleBoxFlat.new()
    style.bg_color = Color("192c22")
    style.border_color = Color("968159")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(20)
    panel.add_theme_stylebox_override("panel", style)
    cards.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    panel.add_child(column)
    var name_label: Label = world.label(str(data.get("world_name", "Saved multiplayer world" if data.has("civilizations") else "Original settlement")), 23, Color("eee1bf"))
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(name_label)
    var humans := 0
    var ai := {"Easy": 0, "Normal": 0, "Hard": 0}
    for player in players:
        if player.get("ai", false):
            var level := str(player.get("difficulty", "Normal"))
            if ai.has(level): ai[level] += 1
        else: humans += 1
    var day := int(float(data.get("day", 0)))
    var info := "%s\n%d players · AI: %d Easy / %d Medium / %d Hard\nYear %d · Day %d" % [role, humans, ai.Easy, ai.Normal, ai.Hard, floori(float(day) / 360.0) + 1, day % 360 + 1]
    var civilization := str(data.get("civilization_name", ""))
    if data.has("civilizations") and data.civilizations.has(world.session.own_token): civilization = str(data.civilizations[world.session.own_token].name)
    if not civilization.is_empty(): info += "\nYour civilization: " + civilization
    if data.has("saved_at"): info += "\nLast saved: " + Time.get_datetime_string_from_unix_time(int(data.saved_at)).replace("T", " ") + " UTC"
    var details: Label = world.label(info, 15, Color("b7c9a9"))
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(details)
    var code := str(data.get("join_code", ""))
    if role.begins_with("Joined") or data.has("civilizations"):
        var field := LineEdit.new()
        field.editable = false
        field.text = code
        field.placeholder_text = "Join code available after hosting this world"
        field.tooltip_text = "Direct connection invitation; the host must be online."
        column.add_child(field)
        if not code.is_empty(): world.game_button(column, "Copy join code", func(): DisplayServer.clipboard_set(code))
    world.game_button(column, "Rejoin world" if path.is_empty() else "Continue world", func(): continue_world(data, path))
    var creator: bool = not data.has("civilizations") or str(data.get("creator", world.session.own_token)) == world.session.own_token
    if not path.is_empty() and creator:
        var rename := LineEdit.new()
        rename.placeholder_text = "Rename your world"
        rename.max_length = 48
        column.add_child(rename)
        world.game_button(column, "Rename", func():
            if rename.text.strip_edges().is_empty(): return
            var current := read_data(path)
            if current.is_empty(): return
            current.world_name = rename.text.strip_edges()
            if world.sim.save_path == path: world.sim.world_name = current.world_name
            if world.session.active and world.session.world_save_path == path and world.multiplayer.is_server():
                world.session.world_name = current.world_name
                world.session.persist()
                refresh()
                return
            var file := FileAccess.open(path, FileAccess.WRITE)
            if file: file.store_string(JSON.stringify(current))
            refresh())

func prepare_switch() -> void:
    if is_instance_valid(world.intro_panel): world.intro_panel.get_parent().queue_free()
    if world.session.active or world.session.connecting: world.session.leave()
    world.sim.save_game()
    world.running = false

func create_solo() -> void:
    prepare_switch()
    world.sim = Simulation.new()
    world.sim.save_path = new_path("solo")
    world.sim.world_name = chosen_name()
    world.sim.tick(0)
    world.sim.save_game()
    enter_solo()

func enter_solo() -> void:
    selected = true
    world.session.world_changed()
    world.research_screen.selected = "Toolmaking"
    world.play_button.text = "Resume"
    hide()
    if not world.sim.has_seen_intro: world.show_intro()

func continue_world(data: Dictionary, path: String) -> void:
    if path.is_empty():
        prepare_switch()
        message.text = world.session.join_game(str(data.get("civilization_name", "My civilization")), str(data.get("join_code", "")), 24567)
        return
    if data.has("civilizations"):
        prepare_switch()
        world.session.world_save_path = path
        if data.civilizations.has(world.session.own_token):
            world.multiplayer_screen.nickname.text = str(data.civilizations[world.session.own_token].name)
        world.multiplayer_screen.resume_world.button_pressed = true
        world.multiplayer_screen.world_title.text = str(data.get("world_name", "Saved world"))
        world.multiplayer_screen.port.value = int(data.get("host_port", 24567))
        world.multiplayer_screen.pages.current_tab = 0
        world.multiplayer_screen.show()
        return
    prepare_switch()
    world.sim = Simulation.new()
    world.sim.save_path = path
    world.sim.load_game()
    enter_solo()

func remember_joined(state: Dictionary, players: Array, day: float) -> void:
    if world.session.world_id.is_empty(): return
    var code := "civilization://join?address=%s&port=%d&protocol=%d&world=%s" % [world.session.joining_address.uri_encode(), world.session.joining_port, world.session.PROTOCOL_VERSION, world.session.world_id]
    joined[world.session.world_id] = {"world_name": state.get("world_name", "Shared world"), "civilization_name": state.get("civilization_name", "My civilization"), "players": players.duplicate(true), "day": day, "join_code": code, "saved_at": Time.get_unix_time_from_system()}
    if joined_timer >= 15:
        joined_timer = 0
        save_joined()

func save_joined() -> void:
    if "--capture" in OS.get_cmdline_user_args(): return
    DirAccess.make_dir_recursive_absolute(root_path())
    var file := FileAccess.open(root_path() + "/joined.json", FileAccess.WRITE)
    if file: file.store_string(JSON.stringify(joined))

func _process(delta: float) -> void:
    joined_timer += delta

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST: save_joined()
