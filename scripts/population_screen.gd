extends Control

var world: Node3D
var summary: Label
var professions: Label
var apprentices: Label
var response: Label
var target_controls: Dictionary = {}
var future_controls: Dictionary = {}
var training_buttons: Dictionary = {}
var automatic: CheckBox
var migration: CheckBox
var families: CheckBox

func heading(value: String, at: Vector2, size: int = 18) -> Label:
    var item: Label = world.label(value, size, Color("e8dfc6"))
    item.position = at
    add_child(item)
    return item

func panel(at: Vector2, size: Vector2) -> void:
    var item := Panel.new()
    item.position = at
    item.size = size
    var style := StyleBoxFlat.new()
    style.bg_color = Color("192820")
    style.border_color = Color("685f43")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    item.add_theme_stylebox_override("panel", style)
    add_child(item)

func checkbox(value: String, at: Vector2, action: Callable) -> CheckBox:
    var item := CheckBox.new()
    item.text = value
    item.position = at
    item.focus_mode = Control.FOCUS_NONE
    item.toggled.connect(action)
    add_child(item)
    return item

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.color = Color("101b18")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    heading("PEOPLE & THE SETTLEMENT", Vector2(50, 30), 13)
    heading("A civilization begins with its people", Vector2(50, 55), 30)
    var back := Button.new()
    back.text = "Return to settlement · Esc"
    back.position = Vector2(1140, 50)
    back.size = Vector2(240, 40)
    back.focus_mode = Control.FOCUS_NONE
    back.pressed.connect(func(): hide())
    add_child(back)
    panel(Vector2(40, 135), Vector2(365, 515))
    panel(Vector2(430, 135), Vector2(530, 515))
    panel(Vector2(985, 135), Vector2(415, 515))
    heading("SETTLEMENT CONDITION", Vector2(60, 155), 14)
    summary = heading("", Vector2(60, 195), 13)
    summary.size.x = 325
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary.add_theme_constant_override("line_spacing", -3)
    var happiness := Button.new()
    happiness.text = "Show happiness influences"
    happiness.position = Vector2(60, 435)
    happiness.size = Vector2(320, 28)
    happiness.focus_mode = Control.FOCUS_NONE
    happiness.pressed.connect(func(): world.happiness_panel.show())
    add_child(happiness)
    migration = checkbox("Welcome migrants", Vector2(60, 468), func(value): world.order("policy", ["allow_migration", value]))
    families = checkbox("Support population growth", Vector2(60, 506), func(value): world.order("policy", ["allow_births", value]))
    var explanation := heading("Migrants need spare housing, food,\nand happiness of at least 60.\nChildren enter the workforce at 16.\nElders retire at 65 and may live to 75.", Vector2(60, 560), 13)
    explanation.add_theme_color_override("font_color", Color("a1b49d"))
    heading("WORKFORCE PRIORITIES", Vector2(450, 155), 14)
    heading("Current %", Vector2(640, 191), 13)
    heading("Next generation %", Vector2(810, 191), 13)
    for i in range(world.sim.JOBS.size()):
        var job: String = world.sim.JOBS[i]
        var y := 232 + i * 48
        heading(job, Vector2(450, y + 7), 16)
        for future in [false, true]:
            var spinner := SpinBox.new()
            spinner.position = Vector2(640 if not future else 820, y)
            spinner.size = Vector2(100, 35)
            spinner.min_value = 0
            spinner.max_value = 100
            spinner.suffix = "%"
            spinner.get_line_edit().focus_mode = Control.FOCUS_NONE
            spinner.value_changed.connect(func(value): world.order("target", [job, int(value), future]); refresh())
            add_child(spinner)
            if future: future_controls[job] = spinner
            else: target_controls[job] = spinner
    automatic = checkbox("Maintain percentages as the workforce changes", Vector2(450, 540), func(value):
        world.order("policy", ["automatic_workforce", value])
        world.refresh_game())
    heading("Totals cannot exceed 100%; the remainder is unassigned.\nLocked jobs cannot receive current workers.\nFuture targets guide children's education once a school\nand the required profession technology are available.", Vector2(450, 575), 12)
    heading("TRAINING & PROFESSIONS", Vector2(1005, 155), 14)
    professions = heading("", Vector2(1005, 192), 14)
    for i in range(world.sim.JOBS.size()):
        var job: String = world.sim.JOBS[i]
        var action := Button.new()
        action.position = Vector2(1005, 320 + i * 40)
        action.size = Vector2(375, 34)
        action.text = "Train a " + job.to_lower() + " specialist"
        action.focus_mode = Control.FOCUS_NONE
        action.pressed.connect(func(): response.text = world.order("train", [job]); refresh())
        add_child(action)
        training_buttons[job] = action
    heading("60 days · 1 food + 2 wood per trainee\nTwo camp places; a school provides four places,\nfaster training, child education, and +25% research.", Vector2(1005, 578), 13)
    panel(Vector2(40, 680), Vector2(1360, 190))
    heading("APPRENTICESHIPS", Vector2(60, 700), 14)
    apprentices = heading("", Vector2(60, 730), 15)
    response = heading("Specialists are assigned to matching duties first. Retraining preserves the person, but changes their profession.", Vector2(60, 837), 13)
    visibility_changed.connect(func():
        if visible:
            world.dragging = false
            world.orbiting = false
            refresh())
    hide()
    refresh()

func refresh() -> void:
    var sim = world.sim
    var food_days: float = sim.resources.food / maxf(0.001, sim.food_need())
    summary.text = "%d people\n%d working-age adults · %d children\n%d elders\nHappiness: %.0f / 100\n%s\nHousing: %d / %d occupied\nFood reserve: %.0f days\nRecent food change: %+.2f / day\n%s\n%s" % [sim.population, sim.adults(), sim.children(), sim.population - sim.adults() - sim.children(), sim.happiness, "Unrest" if sim.happiness < 40 else "Content" if sim.happiness >= 60 else "Concerned", sim.population, sim.housing(), food_days, sim.daily_food_change, "Treated water" if sim.completed("Well") > 0 else "Water needs treatment", " · ".join(sim.conditions)]
    summary.text += "\nAvailable civilian workforce: %d\nPregnancy / birth recovery leave: %d" % [sim.workforce_capacity(), sim.birth_leave_count()]
    automatic.set_pressed_no_signal(sim.automatic_workforce)
    migration.set_pressed_no_signal(sim.allow_migration)
    families.set_pressed_no_signal(sim.allow_births)
    families.disabled = true
    families.text = "Births: " + str(sim.government.births) + " · Town Hall"
    var counts: Dictionary = {"General": 0}
    var training: Array[String] = []
    for job in sim.JOBS: counts[job] = 0
    for person in sim.people:
        if person.age >= 16 and person.age < 65 and not sim.on_birth_leave(person): counts[person.profession] = int(counts.get(person.profession, 0)) + 1
        if not person.training.is_empty():
            training.append("Settler %d · %s · %.0f%%" % [person.id, person.training, person.training_progress / 60.0 * 100])
    professions.text = "General workers: %d\nGatherers %d · Fishers %d · Loggers %d\nQuarriers %d · Builders %d · Farmers %d\nProfession counts exclude pregnancy/recovery leave.\nTrained workers add skill to matching jobs.\nLearning temporarily reduces work by 25%%." % [counts.General, counts.Gathering, counts.Fishing, counts.Logging, counts.Quarrying, counts.Construction, counts.Farming]
    apprentices.text = "\n".join(training) if not training.is_empty() else "No training underway. Choose an unlocked profession above."
    for job in sim.JOBS:
        target_controls[job].set_block_signals(true)
        future_controls[job].set_block_signals(true)
        target_controls[job].max_value = 100
        future_controls[job].max_value = 100
        target_controls[job].set_value_no_signal(sim.workforce_targets[job])
        future_controls[job].set_value_no_signal(sim.generation_targets[job])
        target_controls[job].editable = sim.job_unlocked(job)
        target_controls[job].tooltip_text = "Requires " + sim.JOB_TECH[job] if not sim.job_unlocked(job) else "Share of working-age adults."
        target_controls[job].max_value = 100 - sim.target_total(sim.workforce_targets) + sim.workforce_targets[job]
        future_controls[job].max_value = 100 - sim.target_total(sim.generation_targets) + sim.generation_targets[job]
        target_controls[job].set_block_signals(false)
        future_controls[job].set_block_signals(false)
        # Restore SpinBox's arrow states after the blocked range updates.
        target_controls[job].changed.emit()
        future_controls[job].changed.emit()
        training_buttons[job].disabled = not sim.job_unlocked(job)
        training_buttons[job].tooltip_text = "Requires " + sim.JOB_TECH[job] if not sim.job_unlocked(job) else "Learn or retrain one adult."
