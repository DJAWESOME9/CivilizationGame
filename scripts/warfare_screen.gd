extends VBoxContainer

const Warfare = preload("res://scripts/warfare.gd")
var world: Node3D
var response: Label
var summary: Label
var pages: TabContainer
var unit_type: OptionButton
var recruit_count: SpinBox
var recruit_button: Button
var recruit_hint: Label
var training_list: Label
var armies_list: ItemList
var details: Label
var tactic: OptionButton
var formation: OptionButton
var autonomy: CheckBox
var retreat: SpinBox
var casualties: SpinBox
var casualty_action: OptionButton
var destroy_buildings: CheckBox
var raze_button: Button
var composition_counts: Dictionary = {}
var defense: OptionButton
var target: OptionButton
var commander: OptionButton
var army_title: LineEdit
var edit_hint: Label
var reserve_hint: Label
var create_button: Button
var defend_button: Button
var release_button: Button
var attack_button: Button
var raid_button: Button
var recall_button: Button
var hold_button: Button
var disband_button: Button
var orders_button: Button
var campaign_details: Label
var reports: Label
var selected_army := -1
var army_signature := ""
var target_signature := ""
var plan_signature := ""
var timer := 0.0

func selector(row: BoxContainer, items: Array) -> OptionButton:
    var item := OptionButton.new()
    for value in items: item.add_item(value)
    row.add_child(item)
    return item

func text(parent: Node, value: String, size: int = 14) -> Label:
    var item: Label = world.label(value, size, Color("c6d2b8"))
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(item)
    return item

func page(title: String) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = title
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    pages.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 10)
    scroll.add_child(column)
    return column

func row(parent: Node) -> HBoxContainer:
    var item := HBoxContainer.new()
    item.add_theme_constant_override("separation", 8)
    parent.add_child(item)
    return item

func command(action: String, args: Array) -> void:
    response.text = world.order(action, args)
    world.sim.save_game()
    world.citizens.sync_people()
    refresh()

func setup(scene: Node3D) -> void:
    world = scene
    name = "Armies"
    add_theme_constant_override("separation", 8)
    summary = text(self, "", 17)
    pages = TabContainer.new()
    pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(pages)
    var column := page("Armies")
    var navigation := row(column)
    world.game_button(navigation, "Training", func(): pages.current_tab = 1)
    world.game_button(navigation, "Create / edit armies", func(): pages.current_tab = 2)
    text(column, "Select an army to assign home defense or issue expedition orders. New forces have no commander and no abilities.", 13)
    armies_list = ItemList.new()
    armies_list.custom_minimum_size.y = 100
    armies_list.item_selected.connect(func(index): selected_army = int(armies_list.get_item_metadata(index)); plan_signature = ""; refresh())
    column.add_child(armies_list)
    details = text(column, "")
    var defense_row := row(column)
    defend_button = world.game_button(defense_row, "Defend this location", func(): command("assign_defense", [selected_army, true]))
    release_button = world.game_button(defense_row, "Release from defense", func(): command("assign_defense", [selected_army, false]))
    text(column, "Expedition destination", 17)
    target = OptionButton.new()
    target.custom_minimum_size.x = 260
    column.add_child(target)
    var attack_row := row(column)
    attack_button = world.game_button(attack_row, "Attack", func(): dispatch("Attack"))
    raid_button = world.game_button(attack_row, "Raid", func(): dispatch("Raid"))
    raze_button = world.game_button(attack_row, "Raze", func(): dispatch("Raze"))
    destroy_buildings = CheckBox.new()
    destroy_buildings.text = "Destroy buildings during Raze"
    destroy_buildings.tooltip_text = "Unchecked: kill residents present and plunder within carrying limits. Checked: also demolish settlement buildings after resistance ends."
    column.add_child(destroy_buildings)
    var messenger_row := row(column)
    hold_button = world.game_button(messenger_row, "Ⅱ", func(): command("messenger", [selected_army, "Hold", []]))
    recall_button = world.game_button(messenger_row, "↩", func(): command("recall", [selected_army]))
    hold_button.tooltip_text = "Send messenger: hold position"
    recall_button.tooltip_text = "Send messenger: return home"
    text(column, "At home, Attack, Raid or Raze dispatches immediately. In the field, destination and plan changes travel by messenger. The army continues its current orders until delivery. Messengers travel three times faster than ordinary armies; one pending messenger per army. Held armies still consume provisions. Attack targets armies only. Raid loads whatever fits while fighting obstructing defenders. Raze attacks residents present; optional demolition follows. All troops carry at most 2 resource units each, including provisions; a full load slows movement by 25%.", 12)
    text(column, "Battle plan", 17)
    var orders := row(column)
    tactic = selector(orders, Warfare.TACTICS)
    formation = selector(orders, Warfare.FORMATIONS)
    autonomy = CheckBox.new()
    autonomy.text = "Commander discretion"
    orders.add_child(autonomy)
    var plan_row := row(column)
    text(plan_row, "Retreat at morale")
    retreat = SpinBox.new()
    retreat.min_value = 15
    retreat.max_value = 70
    retreat.suffix = "% morale"
    retreat.value = 35
    plan_row.add_child(retreat)
    var casualty_row := row(column)
    text(casualty_row, "At casualties (0 = off)")
    casualties = SpinBox.new()
    casualties.min_value = 0
    casualties.max_value = 100
    casualties.suffix = "%"
    casualties.value = 50
    casualty_row.add_child(casualties)
    casualty_action = selector(casualty_row, ["Retreat", "Surrender"])
    orders_button = world.game_button(column, "Apply plan / send messenger", func(): command("army_plan", [selected_army, tactic.get_item_text(tactic.selected), formation.get_item_text(formation.selected), autonomy.button_pressed, int(retreat.value), int(casualties.value), casualty_action.get_item_text(casualty_action.selected)]))
    text(column, "Either enabled threshold triggers its response. Casualties are measured against this battle’s starting strength. Retreating soldiers must reach safety and can be pursued or shot. Surrender gives the winner carried resources up to its army capacity or town storage, abandons excess, and sends surviving troops home. There are no prisoners.", 12)
    var standing := row(column)
    text(standing, "Standing defense policy")
    defense = selector(standing, Warfare.DEFENSES)
    defense.item_selected.connect(func(index): command("defense", [Warfare.DEFENSES[index]]))
    text(column, "Only assigned home armies defend. Civilian rallying requires the Town Hall Fight back policy and sufficient happiness. It can supplement home armies against Raid/Raze; Attack leaves civilians alone. Orders apply offline.", 12)
    campaign_details = text(column, "")
    column = page("Training")
    text(column, "Train units", 22)
    text(column, "Train adults into unassigned reserves, then create armies from fully trained units. Training Grounds provide six training places each; completed Barracks house twelve soldiers each. Equipment is paid when training begins.", 13)
    var recruitment := row(column)
    unit_type = selector(recruitment, Warfare.UNITS.keys())
    recruit_count = SpinBox.new()
    recruit_count.min_value = 1
    recruit_count.max_value = 30
    recruit_count.value = 3
    recruitment.add_child(recruit_count)
    recruit_button = world.game_button(recruitment, "Start training", func(): command("recruit", [unit_type.get_item_text(unit_type.selected), int(recruit_count.value), "None"]))
    recruit_hint = text(column, "")
    training_list = text(column, "")
    world.game_button(column, "Create armies from trained units", func(): pages.current_tab = 2)
    column = page("Create & edit")
    text(column, "Create an army", 22)
    army_title = LineEdit.new()
    army_title.placeholder_text = "Army name"
    army_title.max_length = 32
    column.add_child(army_title)
    var creation := row(column)
    for unit in Warfare.UNITS:
        var unit_row := row(column)
        text(unit_row, unit)
        var amount := SpinBox.new()
        amount.min_value = 0
        amount.max_value = 30
        amount.value = 3 if unit == "Militia" else 0
        unit_row.add_child(amount)
        composition_counts[unit] = amount
    create_button = world.game_button(creation, "Create army", func(): command("form_army", [requested_composition(), army_title.text]))
    reserve_hint = text(column, "")
    text(column, "Edit the army selected on the Armies page", 20)
    edit_hint = text(column, "")
    world.game_button(column, "Use name above for selected army", func(): command("rename_army", [selected_army, army_title.text]))
    world.game_button(column, "Set selected army to unit counts above", func(): command("compose_army", [selected_army, requested_composition()]))
    world.game_button(column, "Load selected army counts", func():
        var selected := Warfare.find_army(world.sim, selected_army)
        var counts := Warfare.composition(selected)
        for unit in counts: composition_counts[unit].value = counts[unit])
    var appointment := row(column)
    commander = selector(appointment, ["None"])
    world.game_button(appointment, "Assign commander", func(): command("appoint", [selected_army, commander.get_item_text(commander.selected)]))
    text(column, "No commanders are granted at the start. Existing saved commanders remain available; acquiring new commanders is a future system. Without one, commander bonuses and discretion are unavailable. Armies can combine Militia, Spearmen and Archers, up to 30 total. Archers form the rear and fire from range.", 12)
    world.game_button(column, "Return selected army to trained reserves", func(): command("reserve_army", [selected_army]))
    disband_button = world.game_button(column, "Dismiss selected army to civilian work", func(): command("disband", [selected_army]))
    world.game_button(column, "Back to armies", func(): pages.current_tab = 0)
    column = page("Battle reports")
    reports = text(column, "")
    response = text(self, "Train units, create an army, then assign defense or choose a destination.", 13)
    refresh()

func dispatch(mission: String) -> void:
    var army := Warfare.find_army(world.sim, selected_army)
    if army.is_empty(): return
    if army.status == "Ready":
        var args: Array = [selected_army, target.get_selected_id()]
        if mission == "Raze": args.append(destroy_buildings.button_pressed)
        command(mission.to_lower(), args)
    else:
        var payload: Array = [target.get_selected_id()]
        if mission == "Raze": payload.append(destroy_buildings.button_pressed)
        command("messenger", [selected_army, mission, payload])

func requested_composition() -> Dictionary:
    var result: Dictionary = {}
    for unit in composition_counts: result[unit] = int(composition_counts[unit].value)
    return result

func open_training() -> void:
    pages.current_tab = 1
    refresh()

func select_force(army_id: int) -> void:
    selected_army = army_id
    plan_signature = ""
    pages.current_tab = 0
    refresh()

func select_destination(slot: int) -> void:
    pages.current_tab = 0
    refresh()
    var index := target.get_item_index(slot)
    if index >= 0: target.select(index)
    response.text = "Choose one of your armies above, then Attack, Raid or Raze. Field armies receive the destination by messenger."

func refresh() -> void:
    var sim = world.sim
    var soldiers := 0
    for army in sim.armies: soldiers += army.soldiers.size()
    summary.text = "%d / %d military housing · %d civilian adults available" % [soldiers, sim.military_capacity(), sim.workforce_capacity()]
    var unit: String = unit_type.get_item_text(unit_type.selected)
    var block := Warfare.recruit_block(sim, unit, int(recruit_count.value), "None")
    var spec: Dictionary = Warfare.UNITS[unit]
    recruit_button.disabled = not block.is_empty() or world.session.connecting
    recruit_hint.text = "%s · %.0f wood + %.0f stone each · %.0f days base training\n%s" % [unit, spec.wood, spec.stone, spec.days, block]
    var training_lines := PackedStringArray()
    var reserves: Dictionary = {}
    for kind in Warfare.UNITS: reserves[kind] = 0
    for army in sim.armies:
        if not army.get("reserve", false) and army.status != "Training": continue
        if army.status == "Ready" and army.get("reserve", false): reserves[army.unit] += army.soldiers.size()
        else: training_lines.append("%d %s · %s · %.0f%%" % [army.soldiers.size(), Warfare.composition_text(army), army.status, minf(100, army.training / Warfare.UNITS[army.unit].days * 100)])
    training_list.text = "Training intakes\n" + ("\n".join(training_lines) if not training_lines.is_empty() else "No units training.")
    reserve_hint.text = "Fully trained reserves\nMilitia: %d · Spearmen: %d · Archers: %d" % [reserves.Militia, reserves.Spearmen, reserves.Archers]
    var requested := requested_composition()
    var total := 0
    var available := true
    for kind in requested:
        total += requested[kind]
        if reserves[kind] < requested[kind]: available = false
    create_button.disabled = not available or total < 1 or total > 30 or world.session.connecting
    var chiefs := Warfare.available_commanders(sim)
    if str(chiefs) != str(commander.get_meta("chiefs", [])):
        commander.set_meta("chiefs", chiefs)
        commander.clear()
        for chief in chiefs: commander.add_item(chief)
    var signature := str(sim.armies)
    if signature != army_signature:
        army_signature = signature
        armies_list.clear()
        for army in sim.armies:
            if army.get("reserve", false): continue
            var index := armies_list.add_item("%s · %s · %s%s" % [Warfare.army_name(army), Warfare.composition_text(army), army.status, " · home defense" if army.get("defend_home", true) else ""])
            armies_list.set_item_metadata(index, int(army.id))
            if selected_army == int(army.id): armies_list.select(index)
    var army := Warfare.find_army(sim, selected_army)
    if army.get("reserve", false): army = {}
    if army.is_empty() and armies_list.item_count > 0:
        selected_army = int(armies_list.get_item_metadata(0))
        army = Warfare.find_army(sim, selected_army)
        armies_list.select(0)
    details.text = "No formed army. Open Training, then Create / edit armies." if army.is_empty() else "%s · %s · Commander: %s\nMorale %.0f · Experience %.0f%% · Carried food %.1f\n%s" % [Warfare.army_name(army), army.status, army.commander, army.morale, army.experience * 100, army.supplies, Warfare.COMMANDERS.get(army.commander, Warfare.COMMANDERS["None"]).description]
    if not army.is_empty(): details.text += "\nLoad %.1f / %.1f · March speed %.0f%%" % [Warfare.carried(army), Warfare.carry_capacity(army), Warfare.load_factor(army) * 100]
    edit_hint.text = "No army selected." if army.is_empty() else "%s · %s · %s" % [Warfare.army_name(army), Warfare.composition_text(army), army.status]
    var next_plan := str([selected_army, army.get("tactic"), army.get("formation"), army.get("autonomy"), army.get("retreat"), army.get("casualty_limit"), army.get("casualty_action")])
    if not army.is_empty() and next_plan != plan_signature:
        plan_signature = next_plan
        tactic.select(Warfare.TACTICS.find(army.tactic))
        formation.select(Warfare.FORMATIONS.find(army.formation))
        autonomy.set_pressed_no_signal(army.autonomy and army.commander != "None")
        retreat.set_value_no_signal(army.retreat)
        casualties.set_value_no_signal(army.get("casualty_limit", 50))
        casualty_action.select(1 if army.get("casualty_action", "Retreat") == "Surrender" else 0)
    autonomy.disabled = army.is_empty() or army.get("commander", "None") == "None"
    defense.select(Warfare.DEFENSES.find(sim.defense_order))
    var next_targets := str(sim.known_civilizations)
    if next_targets != target_signature:
        target_signature = next_targets
        var previous := target.get_selected_id()
        target.clear()
        for contact in sim.known_civilizations.values(): target.add_item(contact.name, int(contact.slot))
        var index := target.get_item_index(previous)
        if index >= 0: target.select(index)
    var home: bool = not army.is_empty() and army.status in ["Ready", "Recovering"]
    var field: bool = not army.is_empty() and army.status in ["Marching", "Holding", "Returning", "Fighting", "Raiding"]
    var pending := false
    var campaign_lines := PackedStringArray()
    for campaign in world.session.visible_campaigns:
        if campaign.own:
            var messages: Array = campaign.get("messengers", [])
            if int(campaign.army) == selected_army: pending = not messages.is_empty()
            campaign_lines.append("%s → %s · %s%s" % [campaign.get("name", "Army"), campaign.defender, campaign.phase, " · Messenger: " + str(messages[0].order) if not messages.is_empty() else ""])
        else: campaign_lines.append("Enemy army · %s" % campaign.phase)
    campaign_details.text = "\n".join(campaign_lines)
    defend_button.disabled = not home or army.get("defend_home", true)
    release_button.disabled = not home or not army.get("defend_home", true)
    orders_button.disabled = army.is_empty() or pending or world.session.connecting
    raid_button.disabled = not (home and army.get("status") == "Ready" or field) or pending or not world.session.active or target.item_count == 0
    attack_button.disabled = raid_button.disabled
    raze_button.disabled = raid_button.disabled
    hold_button.disabled = not field or pending
    recall_button.disabled = not field or pending
    disband_button.disabled = not home
    var report_lines := PackedStringArray()
    for report in sim.battle_reports:
        report_lines.append("Day %.1f · %s → %s\n%s · %s\n%d rounds · %d attacking / %d defending casualties\nPlunder: %.1f food, %.1f wood, %.1f stone\n" % [report.day, report.attacker, report.defender, report.outcome, report.reason, report.rounds, report.attacker_losses, report.defender_losses, report.loot.food, report.loot.wood, report.loot.stone])
    for report in sim.battle_reports:
        if report.get("surrender_loot", {}).is_empty(): continue
        for recipient in report.surrender_loot:
            var seized: Dictionary = report.surrender_loot[recipient]
            report_lines.append("Day %.1f · Surrender resources received by %s: %.1f food, %.1f wood, %.1f stone" % [report.day, report.attacker if recipient == "attacker" else report.defender, seized.food, seized.wood, seized.stone])
    reports.text = "\n".join(report_lines) if not report_lines.is_empty() else "No battle reports yet."

func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    timer += delta
    if timer >= 0.4:
        timer = 0
        refresh()
