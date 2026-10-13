extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Session = preload("res://scripts/multiplayer_session.gd")
const Warfare = preload("res://scripts/warfare.gd")
var failures := 0
var checks := 0
var temporary_save := "/tmp/civilization-scouting-%d.json" % OS.get_process_id()

func _initialize() -> void:
    call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func legacy_snapshot() -> Dictionary:
    var sim = Simulation.new()
    var data: Dictionary = sim.snapshot().duplicate(true)
    data.technologies = ["Toolmaking", "Hunting"]
    data.research = "Scouting"
    data.research_progress = 0.4
    data.research_saved = {"Scouting": 0.4, "Planting": 0.25}
    data.queued_research = "Planting"
    return data

func run_checks() -> void:
    var fresh = Simulation.new()
    check(fresh.technologies == ["Scouting"], "Fresh settlement knows Scouting without unlocking production jobs")
    check(fresh.PREREQUISITES.Scouting.is_empty(), "Scouting has no Hunting prerequisite")
    check(fresh.choose_research("Scouting") == "Already learned.", "Starting knowledge cannot consume research")
    var start_food: float = fresh.resources.food
    fresh.send_scouts(Vector2(-25, 20))
    check(fresh.scout_mission.get("units", []).size() == 3, "Scouts depart before Toolmaking or Hunting")
    check(fresh.resources.food == start_food - 3 and fresh.workforce_capacity() == 27, "Mission charges food and reserves adults")
    fresh.advance(50)
    check(fresh.scout_mission.is_empty() and fresh.workforce_capacity() == 30, "Scouts return and release adults")
    check(fresh.explored.has(fresh.cell_key(Vector2(-25, 20))), "Mission reveals its destination")
    var poor = Simulation.new()
    poor.resources.food = 2.0
    check(poor.send_scouts(Vector2(-25, 20)) == "Scouts need 3 food for the expedition." and poor.scout_mission.is_empty(), "Free scouting still requires supplies")

    var restored = Simulation.new()
    var old := legacy_snapshot()
    restored.restore_snapshot(old)
    check("Scouting" in restored.technologies, "Shared snapshot migration grants Scouting")
    check(restored.research == "Planting" and restored.research_progress == 0.25 and restored.queued_research.is_empty(), "Migration starts queued research with retained progress")
    check(not restored.research_saved.has("Scouting"), "Obsolete Scouting research progress removed")
    restored.restore_snapshot(restored.snapshot().duplicate(true))
    check(restored.technologies.count("Scouting") == 1 and restored.research_progress == 0.25, "Repeated snapshot restores are idempotent")
    old.research = "Toolmaking"
    old.research_progress = 0.2
    old.queued_research = "Scouting"
    var file := FileAccess.open(temporary_save, FileAccess.WRITE)
    file.store_string(JSON.stringify(old))
    file.close()
    var loaded = Simulation.new()
    loaded.save_path = temporary_save
    loaded.load_game()
    check("Scouting" in loaded.technologies and loaded.queued_research.is_empty(), "Older on-disk solo save gains Scouting and clears its queue")
    check(loaded.research == "Toolmaking" and loaded.research_progress >= 0.2, "Other current research remains intact")
    loaded.save_game()
    check("Scouting" in JSON.parse_string(FileAccess.get_file_as_string(temporary_save)).technologies, "Unlocked Scouting persists on save")

    # Exercise host discovery logic for every ordered pair of starting sites.
    var discovery = Session.new()
    for i in range(Warfare.SITES.size()):
        var sim = Simulation.new()
        var site: Vector2 = Warfare.SITES[i]
        sim.world_origin = [site.x + 4, site.y]
        sim.shared_region = true
        discovery.civilizations[str(i)] = {"name": "Player %d" % i, "sim": sim, "slot": i}
    for i in range(Warfare.SITES.size()):
        var sim = discovery.civilizations[str(i)].sim
        for j in range(Warfare.SITES.size()):
            if i == j: continue
            var target: Vector2 = Warfare.SITES[j] - Vector2(sim.world_origin[0], sim.world_origin[1])
            sim.send_scouts(target)
            check(not sim.scout_mission.is_empty(), "Starting site %d can scout site %d without research" % [i, j])
            if sim.scout_mission.is_empty(): continue
            var steps := 0
            while not sim.scout_mission.is_empty() and steps < 1000:
                sim.advance(0.25)
                discovery.update_world_intel()
                steps += 1
            check(sim.known_civilizations.has(str(j)), "Site %d discovers actual civilization %d" % [i, j])
            check(sim.scout_mission.is_empty(), "Site %d mission to %d returns" % [i, j])
            sim.resources.food = 30.0
    discovery.free()

    # Capture mode avoids loading/writing the player's save and identity.
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.session.set_process(false)
    check(scene.exploration_panel.visible and not scene.scout_button.disabled, "Fresh-game UI exposes scouting immediately")
    scene.research_screen.selected = "Scouting"
    scene.research_screen.refresh()
    check(scene.research_screen.start.disabled and scene.research_screen.start.text == "Learned", "Research UI recognizes starting knowledge")
    var session = scene.session
    session.world_save_path = temporary_save
    session.host_game("Scouting test", 25441, 8640.0, false, 1, "Easy")
    check(session.active and session.civilizations.size() == 2, "Local ENet host creates a human and AI civilization")
    if session.active:
        for record in session.civilizations.values():
            check("Scouting" in record.sim.technologies, "Every newly hosted civilization knows Scouting")
            record.sim.technologies.erase("Scouting")
        session.persist()
        session.leave()
        session.host_game("Scouting test", 25441, -1.0, true)
        check(session.active and session.civilizations.size() == 2, "Older world resumes without replacing civilizations")
        for record in session.civilizations.values():
            check("Scouting" in record.sim.technologies, "Resumed host grants Scouting to every saved civilization")
        session.leave()
    scene.queue_free()
    DirAccess.remove_absolute(temporary_save)
    print("Scouting checks: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
    quit(0 if failures == 0 else 1)
