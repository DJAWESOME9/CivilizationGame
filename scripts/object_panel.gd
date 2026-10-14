extends Control

var world: Node3D
var selected: Dictionary = {}
var heading: Label
var status: Label
var progress: ProgressBar
var details: Label
var dismantle_action: Button
var trade_action: Button
var scout_action: Button
var scout_help: Label
var armies_action: Button
var field_response: Label
var field_actions: HBoxContainer
var scout_route: Control
var town_hall: Control
var civic_action: Button
var panel: PanelContainer

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel = PanelContainer.new()
    world.ui_panels.append(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    panel.position = Vector2(-300, 160)
    panel.custom_minimum_size = Vector2(600, 0)
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
    world.game_button(column, "Choose scouting destination on map", func():
        hide()
        world.begin_scout_selection())
    status = world.label("", 17, Color("dec58f"))
    column.add_child(status)
    scout_route = preload("res://scripts/scout_route.gd").new()
    column.add_child(scout_route)
    scout_route.hide()
    progress = ProgressBar.new()
    progress.custom_minimum_size.y = 20
    column.add_child(progress)
    column.add_child(HSeparator.new())
    details = world.label("", 15, Color("c1d0b3"))
    details.custom_minimum_size.x = 556
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(details)
    town_hall = preload("res://scripts/town_hall_screen.gd").new()
    add_child(town_hall)
    town_hall.setup(world)
    civic_action = world.game_button(column, "Policies & standing orders", func(): town_hall.open())
    civic_action.hide()
    dismantle_action = world.game_button(column, "Dismantle", func():
        var message: String = world.order("dismantle", [selected.get("camp_id", "")])
        world.feedback.text = message
        field_response.text = message
        world.refresh_game())
    dismantle_action.hide()
    armies_action = world.game_button(column, "Armies & commanders", func():
        hide()
        world.multiplayer_screen.open_warfare()
        if selected.get("kind", "") == "Training Grounds": world.multiplayer_screen.warfare_page.open_training()
        elif selected.get("kind", "") == "Civilization": world.multiplayer_screen.warfare_page.select_destination(int(selected.slot))
        elif selected.get("kind", "") == "Army": world.multiplayer_screen.warfare_page.select_force(int(selected.get("army", -1))))
    armies_action.hide()
    trade_action = world.game_button(column, "Trade · Barter", func():
        world.multiplayer_screen.open_barter(int(selected.slot))
        hide())
    trade_action.hide()
    field_actions = HBoxContainer.new()
    column.add_child(field_actions)
    var hold_action: Button = world.game_button(field_actions, "Ⅱ", func(): field_response.text = world.order("messenger", [int(selected.get("army", -1)), "Hold", []]); refresh())
    var return_action: Button = world.game_button(field_actions, "↩", func(): field_response.text = world.order("recall", [int(selected.get("army", -1))]); refresh())
    hold_action.tooltip_text = "Send messenger: hold position"
    return_action.tooltip_text = "Send messenger: return home"
    hold_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    field_actions.hide()
    field_response = world.label("", 13, Color("e2c789"))
    field_response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(field_response)
    scout_action = world.game_button(column, "Send 3 settlers to scout", func():
        world.select_scout_land(selected.point)
        var message: String = world.dispatch_scouts(selected.point)
        if message.begins_with("Scouts dispatched") or message == "Order sent to the host.":
            hide()
        else: scout_help.text = message
        world.refresh_game())
    scout_help = world.label("", 13, Color("d9c59c"))
    scout_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(scout_help)
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.left_down = false
            world.orbiting = false)
    hide()

func open_object(info: Dictionary) -> void:
    field_response.text = ""
    selected = info.duplicate(true)
    if selected.get("kind", "") in ["Land", "Oak tree", "Stone deposit", "River stone", "Reeds"] and selected.has("point"):
        world.select_scout_land(selected.point)
    town_hall.hide()
    refresh()
    show()

func refresh() -> void:
    var sim = world.sim
    var kind: String = selected.get("kind", "")
    heading.text = kind
    # Reset only controls that do not belong to this selection. Toggling a
    # visible action (or its container) off and on cancels an ongoing click.
    if kind not in ["Scouting party", "Field", "Oak tree", "Stone deposit", "River stone"] and not selected.has("q") and not selected.has("camp_id"):
        progress.hide()
    scout_route.visible = kind == "Scouting party"
    if kind != "Army" or not selected.get("own", false):
        armies_action.visible = kind == "Civilization" or kind == "Training Grounds"
        field_actions.hide()
    trade_action.visible = kind == "Civilization"
    trade_action.disabled = not world.session.active or world.session.connecting
    if kind not in ["Army", "Civilization", "Training Grounds"]: armies_action.text = "Armies"
    # Keep eligible controls visible during live refreshes: hiding a pressed
    # button cancels its click before the mouse release can activate it.
    dismantle_action.visible = selected.has("camp_id") and sim.job_unlocked("Construction")
    if kind != "Town Hall" or not selected.has("q"): civic_action.hide()
    if kind == "Civilization":
        var contact: Dictionary = sim.known_civilizations.get(str(int(selected.slot)), {})
        if contact.is_empty(): hide(); return
        selected.point = Vector2(contact.point[0], contact.point[1])
    var landscape: bool = kind in ["Land", "Oak tree", "Stone deposit", "River stone", "Reeds", "Civilization"] and selected.has("point")
    scout_action.visible = landscape
    scout_help.visible = landscape
    if landscape:
        var blocked: String = sim.scouting_block(selected.point)
        if world.session.connecting: blocked = "Wait for the shared world to connect."
        scout_action.disabled = not blocked.is_empty()
        scout_action.text = "Send 3 settlers · %d food" % sim.scout_food_cost(selected.point)
        scout_help.text = blocked if not blocked.is_empty() else "Scouts will travel to this location, survey it, and return. Food is packed for the expected trip duration."
    if kind == "Land":
        status.text = "Scouting destination"
        details.text = sim.land_report(selected.point)
        return
    if kind == "Civilization":
        var contact: Dictionary = sim.known_civilizations.get(str(int(selected.slot)), {})
        if contact.is_empty(): hide(); return
        heading.text = contact.name
        status.text = "Currently in sight" if sim.has_live_sight(selected.point) else "Last observed %.1f days ago" % maxf(0.0, sim.day - float(contact.last_seen))
        details.text = "%d people at last observation. Trade resources, send scouts for a fresh observation, or choose an army to attack or raid." % int(contact.population)
        armies_action.text = "Choose army · Attack / Raid"
        armies_action.show()
        return
    if kind == "Army":
        refresh_army()
        return
    if kind == "Scouting party":
        refresh_scouts()
        return
    if selected.has("q"):
        var building: Dictionary = {}
        for candidate in sim.buildings:
            if candidate.q == selected.q and candidate.r == selected.r:
                building = candidate
                break
        if building.is_empty():
            hide()
            return
        civic_action.visible = kind == "Town Hall" and building.progress >= 1
        armies_action.visible = kind == "Training Grounds"
        armies_action.text = "Open training"
        status.text = "%s · Hex %d, %d" % ["Complete" if building.progress >= 1 else "Under construction", building.q, building.r]
        if building.progress < 1:
            progress.show()
            progress.value = building.progress * 100
            var cost: Dictionary = sim.BUILDINGS[kind]
            details.text = "Construction · %.0f%% complete\nWork remaining · %.1f\nConstruction workers · %d across all projects\n\nMaterials paid · %.0f wood · %.0f stone\nBuilders work through projects in the order they were commissioned. Benefits begin when construction is complete.\n\n%s" % [building.progress * 100, (1 - building.progress) * cost.work, sim.effective_assignments().Construction, cost.wood, cost.stone, benefit(kind)]
        elif kind == "Field":
            progress.show()
            progress.value = clampf(building.get("growth", 0.0) * 100, 0, 100)
            var season := int(sim.day / 90) % 4
            var farmers: int = sim.effective_assignments().Farming
            var state := "Growing" if farmers > 0 else "Waiting for farmers"
            if season == 3: state = "Dormant for winter"
            status.text = "%s · Hex %d, %d" % [state, building.q, building.r]
            details.text = "Crop growth · %.0f%%\nHarvest yield · 70 food\nFarmers · %d shared across %d completed fields\n\n%s\n\n%s" % [progress.value, farmers, sim.completed("Field"), sim.season_description(), "Crop Rotation improves growth by 30%." if "Crop Rotation" in sim.technologies else "Research Crop Rotation to improve growth by 30%."]
            if "Waterworks" in sim.technologies and sim.completed("Well") > 0:
                details.text += "\nWell irrigation improves growth by another 25%."
        else:
            progress.hide()
            details.text = benefit(kind)
        return
    if selected.has("camp_id"):
        var id: String = selected.camp_id
        if not sim.camp_object_present(id):
            hide()
            return
        var item: Dictionary = sim.STARTING_OBJECTS[id]
        var queued: bool = sim.camp_dismantling.has(id)
        dismantle_action.visible = sim.job_unlocked("Construction")
        dismantle_action.disabled = queued or world.session.connecting
        dismantle_action.text = "Dismantling queued" if queued else "Dismantle · recover %.0f wood / %.0f stone" % [item.wood, item.stone]
        if queued:
            progress.show()
            progress.value = float(sim.camp_dismantling[id]) * 100
        else:
            progress.hide()
    status.text = "Starting camp"
    match kind:
        "Starting tent":
            details.text = "Each remaining starting tent provides 15 beds.\n\nSettlement housing · %d people / %d beds\nBuild houses to provide permanent homes and improve housing quality." % [sim.population, sim.housing()]
        "Supply cache":
            details.text = "Food · %.1f\nWood · %.1f\nStone · %.1f\n\nShared storage · %.1f / %.0f\nThe starting cache provides 180 capacity until dismantled. Completed storehouses add 200 each." % [sim.resources.food, sim.resources.wood, sim.resources.stone, sim.resources.food + sim.resources.wood + sim.resources.stone, sim.capacity()]
        "Cart":
            details.text = "A supply cart from the settlers’ arrival. It marks the camp’s supplies and does not add storage or production."
        "Campfire":
            details.text = "The settlement’s hearth lights the camp at night.\n\nBuild houses and a well to improve living conditions."
        "Oak tree", "Stone deposit", "River stone":
            status.text = "In sight" if sim.has_live_sight(selected.point) else "Remembered landscape"
            var remaining: float = world.resource_deposits.remaining(sim, selected)
            var resource: String = selected.get("resource", "wood" if kind == "Oak tree" else "stone")
            progress.show()
            progress.value = remaining / maxf(float(selected.get("resource_capacity", 0.0)), 0.001) * 100
            progress.tooltip_text = "%.1f%% of this source remains" % progress.value
            details.text = "Remaining · %.2f %s / %.2f\n\n" % [remaining, resource, float(selected.get("resource_capacity", 0.0))] + sim.land_report(selected.point)
            if remaining <= 0.000001: status.text = "Fully harvested"
            details.text += "\n\n" + ("Assign logging workers after learning Woodcutting to collect timber. Forestry supports woodland regrowth." if kind == "Oak tree" else "Assign quarry workers after learning Stoneworking to extract stone. Deposits are finite.")
        "Reeds":
            status.text = "Riverbank · in sight" if sim.has_live_sight(selected.point) else "Remembered riverbank"
            details.text = sim.land_report(selected.point) + "\n\nRiverbank scenery. Learn Fishing and assign fishing workers to collect food from the river."

    if selected.has("camp_id"):
        var id: String = selected.camp_id
        var item: Dictionary = sim.STARTING_OBJECTS[id]
        details.text += "\n\nDismantling recovers %.0f wood and %.0f stone when complete. Construction workers handle dismantling before new buildings, up to three workers per object. The space stays occupied until finished." % [item.wood, item.stone]
        if kind == "Starting tent": details.text += "\nRemoving this tent removes 15 beds."
        if kind == "Supply cache": details.text += "\nRemoving this cache removes 180 storage capacity. Build a storehouse first to retain storage; excess stocks follow the normal overflow rules."
        if not sim.job_unlocked("Construction"): details.text += "\nResearch Shelter Building to unlock dismantling."
        elif sim.camp_dismantling.has(id):
            status.text = "Dismantling · %.0f%%" % progress.value
            details.text += "\nAssign construction workers and advance time to finish."

func refresh_scouts() -> void:
    var sim = world.sim
    var mission: Dictionary = {}
    var missions: Array = sim.scout_missions if not sim.scout_missions.is_empty() else ([sim.scout_mission] if not sim.scout_mission.is_empty() else [])
    for candidate in missions:
        if candidate.get("started", -1) == selected.get("mission_started", -2) and candidate.get("units", []) == selected.get("mission_units", []):
            mission = candidate
            break
    if mission.is_empty():
        progress.hide()
        scout_route.hide()
        status.text = "Expedition ended"
        details.text = "This scouting party is no longer away. Its settlers are available for work again."
        return
    var destination := Vector2(mission.destination[0], mission.destination[1])
    var point: Vector2 = sim.mission_position(mission)
    var age: float = float(mission.get("progress", sim.day - mission.started))
    var travel: float = mission.travel
    var survey_days: float = sim.mission_survey_duration(mission)
    if float(mission.get("survey_days", 3.0)) < 0.0: survey_days = 3.0
    var stage := "Traveling to destination"
    var next_event := "Arrival"
    var stage_days: float = maxf(0.0, travel - age) / sim.mission_travel_rate(mission) / sim.travel_factor()
    var stage_progress := clampf(age / travel, 0.0, 1.0)
    if age >= travel and age < travel + survey_days:
        stage = "Surveying civilization"
        next_event = "Departure for camp"
        stage_days = (travel + survey_days - age) / sim.travel_factor()
        stage_progress = (age - travel) / maxf(survey_days, 0.001)
    elif age >= travel + survey_days:
        stage = "Returning to camp"
        next_event = "Return to camp"
        stage_days = sim.mission_remaining_days(mission)
        stage_progress = clampf((age - travel - survey_days) / maxf(sim.mission_return_travel(mission), 0.001), 0.0, 1.0)
    status.text = "%d scouts · %s · %d food packed%s" % [mission.units.size(), stage, int(mission.get("food", 0)), " · boat expedition" if mission.get("boat", false) else ""]
    progress.show()
    progress.value = stage_progress * 100
    progress.tooltip_text = "%s · %.0f%% complete" % [stage, stage_progress * 100]
    scout_route.show()
    scout_route.set_route(destination, point, sim.mission_direction(mission), sim.mission_return_point(mission), sim.CAMP_RADIUS, sim.mission_departure_point(mission))
    details.text = "Route · Departure (%.1f, %.1f) → Destination (%.1f, %.1f) → Camp boundary\nCurrent position · (%.1f, %.1f)\n\n%s · approximately %.1f game days\nReturn to camp · approximately %.1f game days\nFood packed · %d\n\nScouts only pause at a destination when they find a civilization. They become available on entering the camp area. Estimates use the current seasonal rate; changing seasons can alter them. Time follows the world clock; solo pause stops the countdown." % [sim.mission_departure_point(mission).x, sim.mission_departure_point(mission).y, destination.x, destination.y, point.x, point.y, next_event, stage_days, sim.mission_remaining_days(mission), int(mission.get("food", 0))]

func refresh_army() -> void:
    var sim = world.sim
    if selected.get("own", false):
        var army := preload("res://scripts/warfare.gd").find_army(sim, int(selected.get("army", -1)))
        if army.is_empty():
            armies_action.hide()
            field_actions.hide()
            status.text = "Army no longer available"
            details.text = "This group has disbanded or lost its remaining soldiers."
            return
        heading.text = preload("res://scripts/warfare.gd").army_name(army)
        armies_action.show()
        armies_action.text = "Army orders · New destination / battle plan"
        field_actions.visible = army.status in ["Marching", "Returning", "Holding", "Fighting", "Raiding"]
        status.text = "Your army · " + str(army.status)
        details.text = "%s\nMorale · %.0f / 100\nExperience · %.0f%%\nTraining · %.0f%%\nCarried food · %.1f\n\nFormation · %s\nTactics · %s\nRetreat below · %.0f morale\nCommander discretion · %s" % [preload("res://scripts/warfare.gd").composition_text(army), army.morale, army.experience * 100, minf(100, army.training / (30.0 if army.unit == "Mixed" else preload("res://scripts/warfare.gd").UNITS[army.unit].days) * 100), army.supplies, army.formation, army.tactic, army.retreat, "Enabled" if army.autonomy else "Disabled"]
        details.text += "\nCasualties · %d%% → %s (0 = off)\nLoad · %.1f / %.1f" % [army.get("casualty_limit", 50), army.get("casualty_action", "Retreat"), preload("res://scripts/warfare.gd").carried(army), preload("res://scripts/warfare.gd").carry_capacity(army)]
        var messenger_pending := false
        for campaign in world.session.visible_campaigns:
            if campaign.own and int(campaign.army) == int(army.id):
                var messages: Array = campaign.get("messengers", [])
                messenger_pending = messenger_pending or not messages.is_empty()
                if not messages.is_empty(): details.text += "\nMessenger en route: " + str(messages[0].order) + ". Current orders continue until arrival."
                details.text += "\n\nExpedition · %s → %s\nBattle rounds · %d" % [campaign.attacker, campaign.defender, campaign.rounds]
        for button in field_actions.get_children(): button.disabled = messenger_pending or world.session.connecting
        details.text += "\n\nUse Army orders for a new destination or battle plan. Orders to field armies travel by messenger."
        return
    var report: Dictionary = {}
    var campaign_id := int(selected.get("campaign", -1))
    for campaign in world.session.visible_campaigns:
        if not campaign.own and int(campaign.id) == campaign_id:
            report = campaign
            break
    if report.is_empty(): report = sim.known_armies.get(str(campaign_id), {})
    heading.text = "Enemy army"
    if report.is_empty():
        status.text = "Contact lost"
        details.text = "This army is no longer at its observed position. Send scouts to find it again."
        return
    var point := Vector2(report.point[0], report.point[1])
    var live: bool = sim.has_live_sight(point)
    status.text = "Currently in sight" if live else "Seen %.1f days ago" % maxf(0.0, sim.day - float(report.last_seen))
    details.text = "Civilization · %s\nObserved position · (%.0f, %.0f)\n%s" % [report.get("attacker", "Unknown"), point.x, point.y, "Activity · " + str(report.phase) if live else "Position and activity may have changed."]
    if report.get("intel_scouted", false):
        details.text += "\n\nScout report · day %.1f\nTroops · %d %s\nFormation · %s\nCommander · %s\nThese details describe the last scout observation." % [report.last_scouted, report.count, report.unit, report.formation, report.commander]
    else:
        details.text += "\n\nTroop count · Unknown\nUnit type · Unknown\nFormation · Unknown\nCommander · Unknown\nSend your scouting party within sight of this army to identify it."
    details.text += "\n\nMorale, experience, supplies, destination and standing orders are hidden."

func benefit(kind: String) -> String:
    var sim = world.sim
    match kind:
        "House": return "Provides %d beds.\nSettlement housing · %d people / %d beds\nPermanent housing improves living conditions." % [15 if "Masonry" in sim.technologies else 10, sim.population, sim.housing()]
        "Storehouse": return "Adds 200 shared storage capacity.\nSettlement storage · %.1f / %.0f\nFood, wood, and stone share this capacity." % [sim.resources.food + sim.resources.wood + sim.resources.stone, sim.capacity()]
        "Field": return "Farmers grow crops here. Each harvest provides 70 food. Growth stops in winter."
        "Well": return "Supplies treated water, removing the untreated-water happiness penalty. With Waterworks, completed wells enable a 25% field-growth bonus."
        "Town Hall": return "Expands the buildable clearing from radius 12 to 16. Click Policies & standing orders to manage government. Influence recharges over time, faster with happier citizens; capacity 10."
        "Pottery Workshop": return "Adds 100 shared storage capacity. The first completed workshop halves remaining spoilage, stacking with Preservation; further workshops add storage only."
        "Boatyard": return "Supplies one reusable boat for river scouting. Available boats · %d / %d. Boats return with their expedition; River Navigation improves future expeditions." % [sim.available_scout_boats(), sim.completed("Boatyard")]
        "Carpenter Workshop": return "First completed workshop: up to +25% construction speed, spending 0.2 wood per extra unit of work. With no wood, construction continues at normal speed. Additional workshops do not stack; dismantling is unchanged. Available wood · %.1f." % sim.resources.wood
        "Bathhouse": return "Requires Waterworks and a completed Well. Adds 6 happiness while a Well supplies water; additional bathhouses do not stack. Water supply · %s." % ("Available" if sim.completed("Well") > 0 else "Missing")
        "Archive": return "Adds 0.50 research points per game day per completed archive. Current total · %.2f points/day." % sim.research_points_per_day()
        "School": return "Supports education and adds a 25% settlement research bonus. Schools also accelerate apprenticeships and increase training places."
        "Training Grounds": return "Trains militia, spearmen and archers. Each completed training ground supports six trainees at full speed; larger intakes share training capacity.\n\nOpen training below to train units, then create armies from fully trained reserves. Recruitment also requires completed barracks with room for the soldiers."
        "Barracks": return "Adds room for 12 soldiers and enables trained military units.\nSettlement military capacity · %d soldiers\nOpen Armies & commanders to manage recruitment." % sim.military_capacity()
        "Palisade": return "Timber fortification unlocked by Carpentry. Its footprint physically blocks troops and ordinary arrows. Can be breached (180 health) or bypassed. Arrow Slits lets nearby defending archers shoot through it."
        "Wall": return "Stone wall section unlocked by Masonry. Its footprint physically blocks troops and ordinary arrows. Stronger than timber (420 health); can be breached or bypassed. Arrow Slits lets nearby defending archers shoot through it. Wall placement matters; a section is not a settlement-wide barrier."
    return ""
