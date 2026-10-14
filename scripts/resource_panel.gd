extends Control

var world: Node3D
var selected := "food"
var heading: Label
var stock: Label
var details: Label
var tabs: Dictionary = {}

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
    panel.position = Vector2(400, 100)
    panel.custom_minimum_size = Vector2(640, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("16271e")
    style.border_color = Color("ac9666")
    style.set_border_width_all(1)
    style.set_content_margin_all(22)
    style.set_corner_radius_all(6)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 16)
    panel.add_child(column)
    var top := HBoxContainer.new()
    column.add_child(top)
    heading = world.label("", 25, Color("eee2c6"))
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(heading)
    var close := Button.new()
    close.text = "Close · Esc"
    close.pressed.connect(func(): hide())
    top.add_child(close)
    var tab_row := HBoxContainer.new()
    column.add_child(tab_row)
    var group := ButtonGroup.new()
    for resource in ["food", "wood", "stone", "storage"]:
        var tab := Button.new()
        tab.text = resource.capitalize()
        tab.toggle_mode = true
        tab.button_group = group
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.pressed.connect(func(): open_resource(resource))
        tab_row.add_child(tab)
        tabs[resource] = tab
    stock = world.label("", 22, Color("eee1bf"))
    column.add_child(stock)
    column.add_child(HSeparator.new())
    details = world.label("", 15, Color("c1d0b3"))
    details.custom_minimum_size.x = 596
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(details)
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.left_down = false
            world.orbiting = false
            refresh())
    hide()

func open_resource(resource: String) -> void:
    selected = resource
    refresh()
    show()

func refresh() -> void:
    var sim = world.sim
    var used: float = sim.resources.food + sim.resources.wood + sim.resources.stone
    var free: float = maxf(0, sim.capacity() - used)
    var work: Dictionary = sim.effective_assignments()
    heading.text = selected.capitalize() + " details"
    tabs[selected].set_pressed_no_signal(true)
    stock.text = "Available · %.1f %s" % [sim.resources.get(selected, 0), selected]
    match selected:
        "food":
            var ledger: Dictionary = sim.food_ledger
            var net: float = ledger.production - ledger.consumption - ledger.spoilage - ledger.overflow
            details.text = "Latest production · +%.2f / game day\nConsumed · −%.2f / day\nSpoilage · −%.2f / day\nStorage overflow · −%.2f / day\nNet change · %+.2f / day\n\nCurrent food requirement · %.2f / day\nWorkers · %d gathering · %d fishing · %d farming\nCompleted fields · %d\n\nGathering and fishing supply food continuously. Each field harvest supplies 70 food. Food is also used for scouting, training, and army expeditions.\nRates describe the latest simulation interval; harvests can cause spikes." % [ledger.production, ledger.consumption, ledger.spoilage, ledger.overflow, net, sim.food_need(), work.Gathering, work.Fishing, work.Farming, sim.completed("Field")]
        "wood":
            details.text = "Logging workers · %d\nForest reserve · %.1f wood\n\nLogging supplies wood for buildings, training, and military equipment. Learn Woodcutting to unlock loggers. Forestry enables regrowth; woodland does not regrow in winter. Winter slows logging.\n\nWhen storage is full, newly cut wood stays at its source." % [work.Logging, sim.forest]
        "stone":
            details.text = "Quarry workers · %d\nStone deposit remaining · %.1f stone\n\nQuarrying supplies stone for buildings and military equipment. Learn Stoneworking to unlock quarry workers and improve their tools. Winter slows extraction. Stone deposits are finite.\n\nWhen storage is full, newly quarried stone stays at its source." % [work.Quarrying, sim.quarry]
        "storage":
            stock.text = "Used · %.1f / %.0f" % [used, sim.capacity()]
            details.text = "Food · %.1f\nWood · %.1f\nStone · %.1f\nFree space · %.1f\nCompleted storehouses · %d\n\nAll three resources share storage. The settlement starts with 180 capacity; each completed storehouse adds 200 and each pottery workshop adds 100.\n\nAt capacity, newly extracted wood and stone stay at their source. Food that cannot fit is lost. Construction materials are paid when a building is commissioned and are already deducted from these stocks." % [sim.resources.food, sim.resources.wood, sim.resources.stone, free, sim.completed("Storehouse")]
    if selected != "storage":
        if selected in ["wood", "stone"]:
            details.text = "Latest production · +%.2f / game day\n\n" % float(sim.material_production.get(selected, 0.0)) + details.text
            details.text += "\nRates show materials collected during the latest simulation interval, after storage limits; building and equipment costs are separate."
        details.text += "\n\nShared storage · %.1f / %.0f used · %.1f free" % [used, sim.capacity(), free]
