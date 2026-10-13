extends VBoxContainer

const Warfare = preload("res://scripts/warfare.gd")
var world: Node3D
var response: Label
var summary: Label
var unit_type: OptionButton
var recruit_count: SpinBox
var commander: OptionButton
var recruit_button: Button
var recruit_hint: Label
var armies_list: ItemList
var details: Label
var tactic: OptionButton
var formation: OptionButton
var autonomy: CheckBox
var retreat: SpinBox
var defense: OptionButton
var target: OptionButton
var raid_button: Button
var recall_button: Button
var disband_button: Button
var orders_button: Button
var map: Control
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

func setup(scene: Node3D) -> void:
    world = scene
    name = "Warfare"
    add_theme_constant_override("separation", 8)
    summary = text(self, "", 17)
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(tabs)
    var scroll := ScrollContainer.new()
    scroll.name = "Armies & orders"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 10)
    scroll.add_child(column)
    var row := HBoxContainer.new()
    column.add_child(row)
    unit_type = selector(row, Warfare.UNITS.keys())
    recruit_count = SpinBox.new()
    recruit_count.min_value = 1
    recruit_count.max_value = 30
    recruit_count.value = 3
    row.add_child(recruit_count)
    commander = selector(row, Warfare.COMMANDERS.keys())
    recruit_button = world.game_button(row, "Recruit & train", func():
        response.text = world.order("recruit", [unit_type.get_item_text(unit_type.selected), int(recruit_count.value), commander.get_item_text(commander.selected)])
        world.citizens.sync_people()
        world.sim.save_game()
        refresh())
    recruit_hint = text(column, "")
    armies_list = ItemList.new()
    armies_list.custom_minimum_size.y = 95
    armies_list.item_selected.connect(func(index): selected_army = int(armies_list.get_item_metadata(index)); plan_signature = ""; refresh())
    column.add_child(armies_list)
    details = text(column, "")
    var appointment := HBoxContainer.new()
    column.add_child(appointment)
    text(appointment, "Use the commander selected above to lead this group at home.", 12)
    world.game_button(appointment, "Assign commander", func():
        response.text = world.order("appoint", [selected_army, commander.get_item_text(commander.selected)])
        world.sim.save_game()
        refresh())
    var orders := HBoxContainer.new()
    column.add_child(orders)
    tactic = selector(orders, Warfare.TACTICS)
    formation = selector(orders, Warfare.FORMATIONS)
    autonomy = CheckBox.new()
    autonomy.text = "Commander discretion"
    orders.add_child(autonomy)
    retreat = SpinBox.new()
    retreat.min_value = 15
    retreat.max_value = 70
    retreat.suffix = "% morale"
    retreat.value = 35
    retreat.custom_minimum_size.x = 130
    orders.add_child(retreat)
    orders_button = world.game_button(orders, "Apply orders", func():
        response.text = world.order("army_plan", [selected_army, tactic.get_item_text(tactic.selected), formation.get_item_text(formation.selected), autonomy.button_pressed, int(retreat.value)])
        world.sim.save_game())
    var attack_row := HBoxContainer.new()
    column.add_child(attack_row)
    target = OptionButton.new()
    target.custom_minimum_size.x = 200
    attack_row.add_child(target)
    raid_button = world.game_button(attack_row, "Launch raid", func():
        response.text = world.order("raid", [selected_army, target.get_selected_id()])
        refresh())
    recall_button = world.game_button(attack_row, "Recall army", func(): response.text = world.order("recall", [selected_army]))
    disband_button = world.game_button(attack_row, "Disband at home", func():
        response.text = world.order("disband", [selected_army])
        world.sim.save_game()
        world.citizens.sync_people()
        refresh())
    var defense_row := HBoxContainer.new()
    column.add_child(defense_row)
    text(defense_row, "Offline defense")
    defense = selector(defense_row, Warfare.DEFENSES)
    defense.item_selected.connect(func(index): response.text = world.order("defense", [Warfare.DEFENSES[index]]); world.sim.save_game())
    text(column, "Hold: ready armies defend; if none are ready, up to eight civilians form emergency militia. Counterattack: +10% defensive strength. Preserve people: defenders withdraw earlier; undefended civilians avoid battle and raiders take less.\nSoldiers stop civilian work. Training takes time; every unit needs training grounds. Barracks provide housing for 12 soldiers each. Each training ground trains six people at full speed; larger intakes take longer. Expeditions require Scouting and carried food. Plans can change during a battle.", 12)
    campaign_details = text(column, "")
    text(column, "Zoom out and drag the main civilization map to see the world. Send scouts to discover settlements; old observations remain dated until seen again.", 12)
    var reports_scroll := ScrollContainer.new()
    reports_scroll.name = "Battle reports"
    tabs.add_child(reports_scroll)
    reports = text(reports_scroll, "")
    response = text(self, "Recruit a group, let it train, then issue orders through its commander.", 13)
    refresh()

func refresh() -> void:
    var sim = world.sim
    var soldiers := 0
    for army in sim.armies: soldiers += army.soldiers.size()
    summary.text = "%d / %d military housing · %d civilian adults available · defense: %s" % [soldiers, sim.military_capacity(), sim.workforce_capacity(), sim.defense_order]
    var unit: String = unit_type.get_item_text(unit_type.selected)
    var chief: String = commander.get_item_text(commander.selected)
    var block := Warfare.recruit_block(sim, unit, int(recruit_count.value), chief)
    var spec: Dictionary = Warfare.UNITS[unit]
    recruit_button.disabled = not block.is_empty() or world.session.connecting
    recruit_hint.text = "%s: attack %.1f / defense %.1f · %.0f wood + %.0f stone each · %.0f days training. %s\n%s: %s" % [unit, spec.attack, spec.defense, spec.wood, spec.stone, spec.days, block, chief, Warfare.COMMANDERS[chief].description]
    var signature := str(sim.armies)
    if signature != army_signature:
        army_signature = signature
        armies_list.clear()
        for army in sim.armies:
            var index := armies_list.add_item("%s · %d %s · %s · morale %.0f" % [army.commander, army.soldiers.size(), army.unit, army.status, army.morale])
            armies_list.set_item_metadata(index, int(army.id))
            if selected_army == int(army.id): armies_list.select(index)
    var army := Warfare.find_army(sim, selected_army)
    if army.is_empty() and not sim.armies.is_empty():
        selected_army = int(sim.armies[0].id)
        army = sim.armies[0]
        armies_list.select(0)
    details.text = "No army selected." if army.is_empty() else "%s · %s · %.0f%% training · experience %.0f%% · %.1f expedition food\n%s" % [army.commander, army.status, minf(100, army.training / Warfare.UNITS[army.unit].days * 100), army.experience * 100, army.supplies, Warfare.COMMANDERS[army.commander].description]
    var next_plan := str([selected_army, army.get("tactic"), army.get("formation"), army.get("autonomy"), army.get("retreat")])
    if not army.is_empty() and next_plan != plan_signature:
        plan_signature = next_plan
        tactic.select(Warfare.TACTICS.find(army.tactic))
        formation.select(Warfare.FORMATIONS.find(army.formation))
        autonomy.set_pressed_no_signal(army.autonomy)
        retreat.set_value_no_signal(army.retreat)
    defense.select(Warfare.DEFENSES.find(sim.defense_order))
    var next_targets := str(world.session.roster) + str(world.session.cached_own.get("slot", -1)) + str(sim.known_civilizations.keys())
    if next_targets != target_signature:
        target_signature = next_targets
        var previous := target.get_selected_id()
        target.clear()
        for player in world.session.roster:
            if player.slot != world.session.cached_own.get("slot", -1) and sim.known_civilizations.has(str(int(player.slot))): target.add_item(player.name + (" · offline" if not player.online else ""), player.slot)
        var index := target.get_item_index(previous)
        if index >= 0: target.select(index)
    orders_button.disabled = army.is_empty()
    raid_button.disabled = army.is_empty() or army.get("status") != "Ready" or not world.session.active or target.item_count == 0 or "Scouting" not in sim.technologies
    recall_button.disabled = army.is_empty() or army.get("status") not in ["Marching", "Fighting"]
    disband_button.disabled = army.is_empty() or army.get("status") not in ["Ready", "Training", "Recovering"]
    var campaign_lines := PackedStringArray()
    for campaign in world.session.visible_campaigns:
        if campaign.own:
            campaign_lines.append("%s → %s · %s · %d %s · round %d · morale %.0f" % [campaign.attacker, campaign.defender, campaign.phase, campaign.count, campaign.unit, campaign.rounds, campaign.morale])
        elif campaign.get("intel_scouted", false):
            campaign_lines.append("Enemy army · %s · %d %s · scouted day %.1f" % [campaign.phase, campaign.count, campaign.unit, campaign.last_scouted])
        else:
            campaign_lines.append("Enemy army · %s · troop details unknown; send scouts" % campaign.phase)
    campaign_details.text = "\n".join(campaign_lines) if not campaign_lines.is_empty() else "No active expeditions. Discover another civilization with scouts before launching a raid."
    var report_lines := PackedStringArray()
    for report in sim.battle_reports:
        report_lines.append("Day %.1f · %s → %s\n%s · %s\n%d rounds · %d attacking / %d defending casualties\nPlunder: %.1f food, %.1f wood, %.1f stone\n" % [report.day, report.attacker, report.defender, report.outcome, report.reason, report.rounds, report.attacker_losses, report.defender_losses, report.loot.food, report.loot.wood, report.loot.stone])
    reports.text = "\n".join(report_lines) if not report_lines.is_empty() else "Battle reports will remain here when you return, including battles fought while you were offline."

func _process(delta: float) -> void:
    if not is_visible_in_tree(): return
    timer += delta
    if timer >= 0.4:
        timer = 0
        refresh()
