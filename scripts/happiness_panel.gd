extends Control

var world: Node3D
var score: Label
var factors: VBoxContainer
var rations: OptionButton
var ledger: Label
var signature := ""

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
    panel.position = Vector2(370, 55)
    panel.custom_minimum_size = Vector2(700, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("16271e")
    style.border_color = Color("ac9666")
    style.set_border_width_all(1)
    style.set_content_margin_all(22)
    style.set_corner_radius_all(6)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 9)
    panel.add_child(column)
    var top := HBoxContainer.new()
    column.add_child(top)
    score = world.label("", 25, Color("eee2c6"))
    score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(score)
    var close := Button.new()
    close.text = "Close · Esc"
    close.focus_mode = Control.FOCUS_NONE
    close.pressed.connect(func(): hide())
    top.add_child(close)
    column.add_child(world.label("These modifiers determine the settlement's actual happiness score.", 13, Color("b5c4ac")))
    column.add_child(HSeparator.new())
    factors = VBoxContainer.new()
    factors.add_theme_constant_override("separation", 8)
    column.add_child(factors)
    column.add_child(HSeparator.new())
    var row := HBoxContainer.new()
    column.add_child(row)
    row.add_child(world.label("Food policy", 15, Color("eee2c6")))
    rations = OptionButton.new()
    rations.add_item("Half rations · −15 happiness")
    rations.add_item("Normal rations")
    rations.add_item("Generous rations · +5 happiness")
    rations.item_selected.connect(func(index):
        world.order("rations", [[0.5, 1.0, 1.25][index]])
        world.refresh_game()
        refresh())
    row.add_child(rations)
    ledger = world.label("", 13, Color("c1d0b3"))
    column.add_child(ledger)
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.left_down = false
            world.orbiting = false
            refresh())
    hide()
    refresh()

func refresh() -> void:
    var sim = world.sim
    score.text = "Happiness · %.1f / 100 · normal work at 50\nConditions below set the target; happiness adjusts gradually." % sim.happiness
    rations.select(0 if sim.ration_level < 1 else 2 if sim.ration_level > 1 else 1)
    var influences: Array = sim.happiness_influences()
    var next_signature := JSON.stringify(influences)
    if next_signature != signature:
        signature = next_signature
        for child in factors.get_children():
            factors.remove_child(child)
            child.queue_free()
        for influence in influences:
            var block := VBoxContainer.new()
            block.add_theme_constant_override("separation", 1)
            factors.add_child(block)
            var row := HBoxContainer.new()
            block.add_child(row)
            var name: Label = world.label(influence.name, 15, Color("e5ddc4"))
            name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            row.add_child(name)
            var value: Label = world.label("%+.1f" % (0.0 if absf(influence.value) < 0.001 else influence.value), 16, Color("daa38b") if influence.value < 0 else Color("b8ce95") if influence.value > 0 else Color("9caa98"))
            row.add_child(value)
            var detail: Label = world.label(influence.detail, 12, Color("9daf99"))
            detail.custom_minimum_size.x = 650
            detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            block.add_child(detail)
    ledger.text = "Food per game day: +%.2f produced · −%.2f consumed · −%.2f spoiled · −%.2f overflow\nRequired at this ration policy: %.2f / day. Harvests can cause temporary production spikes.\nScores are capped at 0–100; needs and policy numbers are provisional." % [sim.food_ledger.production, sim.food_ledger.consumption, sim.food_ledger.spoilage, sim.food_ledger.overflow, sim.food_need()]
