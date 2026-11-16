extends Node

# Presentation only: never animate layout sizes or delay close/navigation actions.
const INK := Color("101d1b")
const BRASS := Color("ad9160")
const IVORY := Color("eee3ca")
var shared_theme: Theme
var reduced_motion := false
var animations: Dictionary = {}

func setup(scene: Node) -> void:
    var preferences := ConfigFile.new()
    if preferences.load("user://interface.cfg") == OK:
        reduced_motion = preferences.get_value("appearance", "reduced_motion", false)
    shared_theme = make_theme()
    install_branch(scene)
    get_tree().node_added.connect(func(node: Node):
        if node is Control and scene.is_ancestor_of(node): install.call_deferred(node))

func box(fill: Color, edge: Color, radius: int = 7) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = edge
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    style.corner_detail = 8
    return style

func make_theme() -> Theme:
    var result := Theme.new()
    result.default_font_size = 14
    for type in ["Button", "OptionButton", "MenuButton"]:
        result.set_stylebox("normal", type, box(Color("253a32"), Color("64725a")))
        result.set_stylebox("hover", type, box(Color("364e40"), Color("c9af76")))
        result.set_stylebox("pressed", type, box(Color("493f2b"), Color("d7b873")))
        result.set_stylebox("disabled", type, box(Color("1d2b27"), Color("39473e")))
        var focus := box(Color(0, 0, 0, 0), Color("e7c886"))
        focus.set_border_width_all(2)
        result.set_stylebox("focus", type, focus)
        result.set_color("font_color", type, IVORY)
        result.set_color("font_hover_color", type, Color("fff2d5"))
        result.set_color("font_pressed_color", type, Color("ffde9c"))
        result.set_color("font_disabled_color", type, Color("7e8c7e"))
    result.set_color("font_color", "Label", IVORY)
    for type in ["LineEdit", "TextEdit"]:
        result.set_stylebox("normal", type, box(INK, Color("5d6a56")))
        result.set_stylebox("focus", type, box(Color("1d3029"), BRASS))
        result.set_color("font_color", type, IVORY)
        result.set_color("font_placeholder_color", type, Color("8a9b88"))
        result.set_color("caret_color", type, Color("ebcb8d"))
        result.set_color("selection_color", type, Color("596c4a"))
    result.set_stylebox("panel", "PanelContainer", box(Color("1c2e28"), Color("786d4e")))
    result.set_stylebox("panel", "Panel", box(INK, Color("786d4e")))
    var track := box(Color("101c18"), Color("475440"), 4)
    track.set_content_margin_all(3)
    result.set_stylebox("background", "ProgressBar", track)
    var fill := box(Color("ac9156"), Color("d2b978"), 3)
    fill.set_content_margin_all(0)
    result.set_stylebox("fill", "ProgressBar", fill)
    result.set_color("font_color", "ProgressBar", Color("fff0d1"))
    result.set_color("font_outline_color", "ProgressBar", INK)
    result.set_constant("outline_size", "ProgressBar", 3)
    for type in ["TabContainer", "TabBar"]:
        result.set_stylebox("tab_selected", type, box(Color("334739"), BRASS))
        result.set_stylebox("tab_unselected", type, box(Color("1a2a25"), Color("455443")))
        result.set_stylebox("tab_hovered", type, box(Color("2a4033"), BRASS))
        result.set_color("font_selected_color", type, Color("ffe2a5"))
        result.set_color("font_unselected_color", type, Color("a6b59d"))
    result.set_stylebox("panel", "TabContainer", box(Color("17271f"), Color("596148")))
    var rule := StyleBoxLine.new()
    rule.color = Color("6e6a4a")
    rule.thickness = 1
    result.set_stylebox("separator", "HSeparator", rule)
    result.set_constant("separation", "HSeparator", 10)
    var tooltip := box(Color("10211d"), BRASS)
    tooltip.set_content_margin_all(12)
    tooltip.shadow_color = Color(0, 0, 0, 0.4)
    tooltip.shadow_size = 8
    result.set_stylebox("panel", "TooltipPanel", tooltip)
    result.set_color("font_color", "TooltipLabel", IVORY)
    return result

func install_branch(node: Node) -> void:
    if node is Control: install(node)
    for child in node.get_children(): install_branch(child)

func install(node: Node) -> void:
    if not is_instance_valid(node) or node.is_queued_for_deletion(): return
    if node.has_meta("interface_styled"): return
    node.set_meta("interface_styled", true)
    var control := node as Control
    if not control.get_parent() is Control: control.theme = shared_theme
    # Keep local status colors and padding; add the same material finish to frames.
    if control is PanelContainer or control is Panel:
        if control.has_theme_stylebox_override("panel"):
            var original := control.get_theme_stylebox("panel") as StyleBoxFlat
            if original != null:
                var frame := original.duplicate() as StyleBoxFlat
                frame.set_corner_radius_all(9)
                frame.corner_detail = 8
                frame.border_width_top = maxi(2, frame.border_width_top)
                frame.shadow_color = Color(0.015, 0.025, 0.02, 0.48)
                frame.shadow_size = 12
                frame.shadow_offset = Vector2(0, 5)
                control.add_theme_stylebox_override("panel", frame)
    if control is Button and not control is CheckBox and not control is CheckButton:
        control.mouse_entered.connect(func(): button_light(control, true))
        control.mouse_exited.connect(func(): button_light(control, false))
    control.tree_exiting.connect(func():
        var id := control.get_instance_id()
        if animations.has(id):
            var tween: Tween = animations[id]
            if tween.is_valid(): tween.kill()
            animations.erase(id))
    var root_screen := not control.get_parent() is Control
    var floating_frame := control is PanelContainer and (root_screen or (control.get_parent() is Control and not control.get_parent().get_parent() is Control))
    var tab_page := control.get_parent() is TabContainer
    if root_screen or tab_page or floating_frame:
        control.visibility_changed.connect(func(): reveal(control, floating_frame))
        if control.is_visible_in_tree(): reveal(control, floating_frame)

func reveal(control: Control, lift: bool = false) -> void:
    if not is_instance_valid(control): return
    var id := control.get_instance_id()
    if animations.has(id):
        var previous: Tween = animations[id]
        if previous.is_valid(): previous.kill()
        animations.erase(id)
    control.modulate.a = 1.0
    if lift: control.scale = Vector2.ONE
    if not control.is_visible_in_tree() or reduced_motion: return
    control.modulate.a = 0.0
    var tween := control.create_tween().set_parallel(true)
    animations[id] = tween
    tween.tween_property(control, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if lift:
        control.pivot_offset = control.size * 0.5
        control.scale = Vector2(0.98, 0.98)
        tween.tween_property(control, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.chain().tween_callback(func(): animations.erase(id))

func button_light(button: Button, hovered: bool) -> void:
    var old = button.get_meta("hover_tween", null)
    if old is Tween and old.is_valid(): old.kill()
    var target := Color(1.08, 1.06, 1.02) if hovered and not button.disabled else Color.WHITE
    if reduced_motion:
        button.self_modulate = target
        return
    var tween := button.create_tween()
    button.set_meta("hover_tween", tween)
    tween.tween_property(button, "self_modulate", target, 0.12)

func set_reduced_motion(value: bool) -> void:
    reduced_motion = value
    if value:
        for id in animations.keys():
            var tween: Tween = animations[id]
            if tween.is_valid(): tween.kill()
            var control := instance_from_id(id) as Control
            if is_instance_valid(control):
                control.modulate.a = 1.0
                control.scale = Vector2.ONE
        animations.clear()
    var preferences := ConfigFile.new()
    preferences.load("user://interface.cfg")
    preferences.set_value("appearance", "reduced_motion", value)
    if "--capture" not in OS.get_cmdline_user_args(): preferences.save("user://interface.cfg")
