extends Control

var world: Node3D
var summary: Label
var result: Label
var start_days: SpinBox
var stop_days: SpinBox
var groups: Array = []
var policy_buttons: Dictionary = {}
var policy_status: Dictionary = {}
var policy_grid: GridContainer
const POLICY_TILE_SIZE = 244.0
var births: OptionButton
var refresh_clock := 0.0
const SOURCES = ["None", "Idle", "Quarrying", "Construction", "Logging"]

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.03, 0.06, 0.04, 0.96)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 32)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margin.add_child(column)
    var top := HBoxContainer.new()
    column.add_child(top)
    var title: Label = world.label("TOWN HALL · Policies & standing orders", 25, Color("eee2c6"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(title)
    world.game_button(top, "Close · Esc", func(): hide())
    summary = world.label("", 16, Color("dec58f"))
    column.add_child(summary)
    result = world.label("", 14, Color("e2c789"))
    column.add_child(result)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 14)
    scroll.add_child(content)
    policy_grid = GridContainer.new()
    policy_grid.add_theme_constant_override("h_separation", 14)
    policy_grid.add_theme_constant_override("v_separation", 14)
    content.add_child(policy_grid)
    scroll.resized.connect(func():
        policy_grid.columns = maxi(1, mini(3, int((scroll.size.x - 18.0 + 14.0) / (POLICY_TILE_SIZE + 14.0)))))
    for name in world.sim.CIVIC_POLICIES:
        var info: Dictionary = world.sim.CIVIC_POLICIES[name]
        var action := Button.new()
        action.custom_minimum_size = Vector2(POLICY_TILE_SIZE, POLICY_TILE_SIZE)
        action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        action.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        action.tooltip_text = info.detail
        action.pressed.connect(func():
            result.text = world.order("civic", [name, true if name == "Community Feast" else not bool(world.sim.government.active.get(name, false))])
            refresh())
        policy_grid.add_child(action)
        var inset := MarginContainer.new()
        inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
        for edge in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 16)
        action.add_child(inset)
        var tile := VBoxContainer.new()
        tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tile.add_theme_constant_override("separation", 8)
        inset.add_child(tile)
        var heading: Label = world.label(name, 18, Color("eee2c6"))
        heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        tile.add_child(heading)
        tile.add_child(world.label("%.0f influence%s" % [info.cost, " + %.2f/day" % info.upkeep if info.upkeep > 0 else ""], 13, Color("dec58f")))
        var detail: Label = world.label(info.detail, 14, Color("c1d0b3"))
        detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
        tile.add_child(detail)
        var status: Label = world.label("", 14, Color("c1d0b3"))
        tile.add_child(status)
        policy_status[name] = status
        policy_buttons[name] = action
    var birth_info: Label = world.label("BIRTH POLICY\nEncouraged · 2 influence: +50% new pregnancies, +3 happiness.\nAllowed · 1 influence to switch: normal new pregnancies, neutral happiness.\nForbidden · 3 influence: no new pregnancies, -12 happiness.\nNew pregnancies need food, spare housing and happiness of at least 50. Existing pregnancies continue. Final 90 pregnancy days and 60 days after birth are leave; population/food needs remain.", 15, Color("c1d0b3"))
    birth_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(birth_info)
    births = OptionButton.new()
    for choice in ["Encouraged", "Allowed", "Forbidden"]: births.add_item(choice)
    content.add_child(births)
    world.game_button(content, "Enact birth policy", func(): result.text = world.order("civic", ["Births", births.get_item_text(births.selected)]); refresh())
    content.add_child(world.label("EMERGENCY FOOD RESPONSE · enable in People\nThresholds use days of food at current rations. Recovery must exceed activation.\nSelected groups temporarily gather in the chosen order; None skips a slot.\nWorkers divert as needed, following your priority; normal assignments resume afterward.\nFood workers, soldiers, scouts, children and elders are excluded. Gathering still needs available wildlife.", 15, Color("c1d0b3")))
    start_days = threshold(content, "Activate below (days)")
    stop_days = threshold(content, "Recover to (days)")
    for i in range(4):
        var row := HBoxContainer.new()
        content.add_child(row)
        row.add_child(world.label("Priority %d" % (i + 1), 15, Color("c1d0b3")))
        var choice := OptionButton.new()
        for source in SOURCES: choice.add_item(source)
        row.add_child(choice)
        groups.append(choice)
    world.game_button(content, "Save food response", func():
        var priority: Array = []
        for choice in groups:
            var source: String = choice.get_item_text(choice.selected)
            if source != "None": priority.append(source)
        result.text = world.order("civic", ["Food response", {"start": start_days.value, "stop": stop_days.value, "groups": priority}])
        refresh())
    hide()

func threshold(parent: Node, caption: String) -> SpinBox:
    var row := HBoxContainer.new()
    parent.add_child(row)
    row.add_child(world.label(caption, 15, Color("c1d0b3")))
    var spin := SpinBox.new()
    spin.min_value = 1
    spin.max_value = 360
    spin.step = 1
    row.add_child(spin)
    return spin

func open() -> void:
    var settings: Dictionary = world.sim.government
    start_days.value = settings.food_start
    stop_days.value = settings.food_stop
    births.select(["Encouraged", "Allowed", "Forbidden"].find(settings.births))
    for i in range(groups.size()):
        groups[i].select(SOURCES.find(settings.food_groups[i]) if i < settings.food_groups.size() else 0)
    result.text = ""
    show()
    refresh()

func refresh() -> void:
    var sim = world.sim
    summary.text = "Influence %.2f / 10 · regeneration %.3f/day before upkeep · happiness %.1f · happiness work modifier %.0f%%\nBirths: %s · Emergency response: %s" % [sim.government.influence, 0.05 + 0.001 * sim.happiness, sim.happiness, (1.0 + (sim.happiness - 50) * 0.005) * 100, sim.government.births, "active" if sim.government.food_active else "inactive"]
    if sim.government.food_active and (sim.wildlife <= 0 or sim.daily_food_change < 0): summary.text += "\nFood response warning: stocks are still falling or gathering resources are exhausted."
    for name in policy_buttons:
        var active: bool = float(sim.government.feast_until) > sim.day if name == "Community Feast" else sim.civic_active(name)
        var locked: bool = name == "Education Priority" and sim.completed("School") == 0
        var button: Button = policy_buttons[name]
        button.disabled = locked or (name == "Community Feast" and active)
        var status: Label = policy_status[name]
        status.text = "Requires a School" if locked else ("Active · %.0f days left" % ceil(sim.government.feast_until - sim.day) if name == "Community Feast" and active else "Active · click to revoke" if active else "Hold feast" if name == "Community Feast" else "Inactive · click to enact")
        status.add_theme_color_override("font_color", Color("baffaa") if active else Color("dec58f") if not locked else Color("889184"))
        for state in ["normal", "hover", "pressed", "disabled", "focus"]:
            button.add_theme_stylebox_override(state, policy_tile_style(active, state))

func policy_tile_style(active: bool, state: String) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("294a30") if active else Color("15241d")
    style.border_color = Color("9adb7c") if active else Color("52634c")
    if state == "hover" or state == "focus":
        style.bg_color = style.bg_color.lightened(0.12)
        style.border_color = Color("c3e6a0") if active else Color("dec58f")
    elif state == "pressed":
        style.bg_color = style.bg_color.lightened(0.06)
    elif state == "disabled" and not active:
        style.bg_color = Color("19201b")
        style.border_color = Color("394239")
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    if active:
        style.shadow_color = Color(0.49, 0.85, 0.35, 0.24)
        style.shadow_size = 6
    return style

func _process(delta: float) -> void:
    if not visible: return
    refresh_clock += delta
    if refresh_clock >= 0.5:
        refresh_clock = 0
        refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        hide()
        get_viewport().set_input_as_handled()
