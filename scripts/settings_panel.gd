extends Control

var world: Node3D
var volume: HSlider
var volume_label: Label
var audio_controls: Dictionary = {}
var hexes: CheckBox
var reduced_motion: CheckBox
var fullscreen: CheckBox
var sensitivity: HSlider
var sensitivity_label: Label
var update_status: Label
var automatic_updates: CheckBox
var update_button: Button
var restart_button: Button

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color(0.025, 0.04, 0.03, 0.78)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: hide())
    add_child(shade)
    var panel := PanelContainer.new()
    panel.position = Vector2(440, 70)
    panel.size = Vector2(560, 760)
    panel.custom_minimum_size.x = 560
    var style := StyleBoxFlat.new()
    style.bg_color = Color("16271e")
    style.border_color = Color("ac9666")
    style.set_border_width_all(1)
    style.set_content_margin_all(24)
    style.set_corner_radius_all(6)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 14)
    scroll.add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    var title: Label = world.label("Settings", 27, Color("eee2c6"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var close := Button.new()
    close.text = "Close · Esc"
    close.focus_mode = Control.FOCUS_NONE
    close.pressed.connect(func(): hide())
    header.add_child(close)
    column.add_child(HSeparator.new())
    volume_label = world.label("", 16, Color("e8dfc6"))
    column.add_child(volume_label)
    volume = HSlider.new()
    volume.min_value = 0
    volume.max_value = 100
    volume.step = 1
    volume.custom_minimum_size.y = 24
    volume.value_changed.connect(func(value):
        world.master_volume = value
        world.apply_audio_volume()
        world.save_settings()
        volume_label.text = "Master volume · %.0f%%" % value)
    column.add_child(volume)
    add_audio_slider(column, "music_volume", "Background music")
    add_audio_slider(column, "ambience_volume", "Outdoor ambience")
    add_audio_slider(column, "effects_volume", "Sound effects")
    column.add_child(world.label("Set any volume to zero to mute it. Audio continues while time is paused.", 12, Color("9daf99")))
    column.add_child(HSeparator.new())
    hexes = CheckBox.new()
    hexes.text = "Show hex lines on the map"
    hexes.focus_mode = Control.FOCUS_NONE
    hexes.toggled.connect(func(value): world.set_hex_lines(value))
    column.add_child(hexes)
    column.add_child(world.label("Building placement temporarily shows hexes even when this is off.", 12, Color("9daf99")))
    fullscreen = CheckBox.new()
    fullscreen.text = "Fullscreen"
    fullscreen.focus_mode = Control.FOCUS_NONE
    fullscreen.toggled.connect(func(value):
        world.fullscreen_preference = value
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
        world.save_settings())
    column.add_child(fullscreen)
    reduced_motion = CheckBox.new()
    reduced_motion.text = "Reduce interface animation"
    reduced_motion.focus_mode = Control.FOCUS_NONE
    reduced_motion.toggled.connect(func(value):
        var appearance = world.get_node_or_null("InterfaceStyle")
        if appearance != null: appearance.set_reduced_motion(value))
    column.add_child(reduced_motion)
    sensitivity_label = world.label("", 16, Color("e8dfc6"))
    column.add_child(sensitivity_label)
    sensitivity = HSlider.new()
    sensitivity.min_value = 0.5
    sensitivity.max_value = 2.0
    sensitivity.step = 0.1
    sensitivity.custom_minimum_size.y = 24
    sensitivity.value_changed.connect(func(value):
        world.zoom_sensitivity = value
        world.save_settings()
        sensitivity_label.text = "Zoom sensitivity · %.1f×" % value)
    column.add_child(sensitivity)
    column.add_child(HSeparator.new())
    var actions := HBoxContainer.new()
    column.add_child(actions)
    var expand := Button.new()
    expand.text = "Expand HUD panels"
    expand.focus_mode = Control.FOCUS_NONE
    expand.pressed.connect(func():
        for name in world.panel_states: world.set_panel_collapsed(name, false))
    actions.add_child(expand)
    var reset := Button.new()
    reset.text = "Reset camera"
    reset.focus_mode = Control.FOCUS_NONE
    reset.pressed.connect(func(): world.reset_camera())
    actions.add_child(reset)
    column.add_child(world.label("Changes apply immediately and are saved on this device.", 12, Color("b5c4ac")))
    column.add_child(HSeparator.new())
    column.add_child(world.label("Game updates", 20, Color("eee2c6")))
    automatic_updates = CheckBox.new()
    automatic_updates.text = "Automatically check and download updates"
    automatic_updates.toggled.connect(func(value):
        if is_instance_valid(world.updater): world.updater.set_automatic(value))
    column.add_child(automatic_updates)
    update_status = world.label("", 14, Color("b5c4ac"))
    update_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(update_status)
    var update_actions := HBoxContainer.new()
    column.add_child(update_actions)
    update_button = world.game_button(update_actions, "Check for updates", func():
        if world.updater.available.is_empty(): world.updater.check_updates()
        else: world.updater.download_update())
    restart_button = world.game_button(update_actions, "Restart and update", func(): world.updater.restart())
    world.game_button(update_actions, "Release downloads", func(): OS.shell_open("https://github.com/DJAWESOME9/CivilizationGame/releases"))
    var update_help: Label = world.label("Updates can download while you play multiplayer. Choose Restart and update to restart now outside a shared world, or queue it during multiplayer to restart automatically after you leave. Saves and player identity stay on this computer.", 12, Color("9daf99"))
    update_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(update_help)
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.left_down = false
            world.orbiting = false
            refresh())
    hide()
    refresh()

func add_audio_slider(column: VBoxContainer, property: String, title: String) -> void:
    var caption: Label = world.label("", 16, Color("e8dfc6"))
    column.add_child(caption)
    var slider := HSlider.new()
    slider.min_value = 0
    slider.max_value = 100
    slider.step = 1
    slider.custom_minimum_size.y = 24
    slider.value_changed.connect(func(value):
        world.set(property, value)
        world.apply_audio_volume()
        world.save_settings()
        caption.text = "%s · %.0f%%" % [title, value])
    column.add_child(slider)
    audio_controls[property] = {"slider": slider, "caption": caption, "title": title}

func refresh() -> void:
    for property in audio_controls:
        var controls: Dictionary = audio_controls[property]
        controls.slider.set_value_no_signal(world.get(property))
        controls.caption.text = "%s · %.0f%%" % [controls.title, world.get(property)]
    volume.set_value_no_signal(world.master_volume)
    volume_label.text = "Master volume · %.0f%%" % world.master_volume
    hexes.set_pressed_no_signal(world.show_hex_lines)
    fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
    sensitivity.set_value_no_signal(world.zoom_sensitivity)
    sensitivity_label.text = "Zoom sensitivity · %.1f×" % world.zoom_sensitivity
    var appearance = world.get_node_or_null("InterfaceStyle")
    if appearance != null: reduced_motion.set_pressed_no_signal(appearance.reduced_motion)
    refresh_updates()

func refresh_updates() -> void:
    if not is_instance_valid(world.updater):
        update_button.disabled = true
        restart_button.disabled = true
        return
    var updater = world.updater
    update_status.text = updater.status
    automatic_updates.set_pressed_no_signal(updater.automatic)
    update_button.text = "Download update" if not updater.available.is_empty() else "Check for updates"
    update_button.disabled = updater.busy or updater.ready_to_restart
    restart_button.disabled = not updater.ready_to_restart
    restart_button.text = "Restart after leaving world" if updater.restart_when_safe else "Restart and update"
    restart_button.tooltip_text = "Queue the update restart until you leave the shared world." if world.session.active or world.session.connecting else "Save and restart to apply the downloaded update."

func _process(_delta: float) -> void:
    if visible and is_instance_valid(world.updater):
        restart_button.disabled = not world.updater.ready_to_restart
        restart_button.text = "Restart after leaving world" if world.updater.restart_when_safe else "Restart and update"
        restart_button.tooltip_text = "Queue the update restart until you leave the shared world." if world.session.active or world.session.connecting else "Save and restart to apply the downloaded update."
