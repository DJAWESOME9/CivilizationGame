extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Session = preload("res://scripts/multiplayer_session.gd")
const Logistics = preload("res://scripts/outposts.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func settlement():
    var sim = Simulation.new()
    sim.save_path = ""
    sim.technologies = Simulation.TECHNOLOGIES.keys()
    sim.resources = {"food": 200.0, "wood": 200.0, "stone": 100.0}
    for i in range(8): sim.buildings.append({"kind": "Storehouse", "progress": 1.0, "q": i, "r": 0})
    sim.reveal_land(Vector2(-4, 0), 65)
    return sim

func progress(sim, days: float) -> void:
    for i in range(ceili(days * 4)):
        sim.day += 0.25
        Logistics.advance(sim, 0.25)

func _initialize() -> void:
    print("Isolated user data: ", OS.get_user_data_dir())
    var sim = settlement()
    sim.explored.clear()
    check(not Logistics.founding_block(sim, 0).is_empty(), "Unsurveyed outpost must be rejected")
    sim.reveal_land(Vector2(-4, 0), 65)
    var before := sim.workforce_capacity()
    Logistics.order(sim, "found_outpost", [0])
    check(sim.outposts.size() == 1 and sim.workforce_capacity() == before - 4, "Founding must reserve four real adults")
    check(sim.resources.wood == 180 and sim.resources.stone == 95 and sim.resources.food == 184, "Founding must reserve exact costs")
    var post: Dictionary = sim.outposts[0]
    var crew: Array = post.units.duplicate()
    sim.prepare_roster(sim.assignments)
    for job in sim.JOBS:
        for person in sim.job_roster[job]: check(int(person.id) not in crew, "Remote worker cannot also work at home")
    check(not Logistics.founding_block(sim, 0).is_empty(), "Duplicate outpost must be rejected")
    progress(sim, 35)
    check(post.stage == "Working", "Founding party must reach site and finish camp")
    check(post.stock > 0 and post.delivered == 0, "Production must wait in camp before first delivery")
    progress(sim, 80)
    check(post.delivered > 0 and sim.resources.stone > 95, "Carrier must deliver stone to town")
    Logistics.order(sim, "outpost_road", [0])
    progress(sim, 25)
    check(is_equal_approx(float(post.road), 1.0), "Crew must complete ordered road")
    var road_duration := Logistics.duration(sim, post)
    post.road = 0.0
    check(is_equal_approx(Logistics.duration(sim, post), road_duration * 2), "Completed road must double travel speed")
    post.road = 1.0
    var state: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
    var restored = Simulation.new()
    restored.save_path = ""
    restored.restore_snapshot(state)
    check(restored.outposts.size() == 1 and restored.outposts[0].units.map(func(id): return int(id)) == crew, "JSON snapshot must restore exact crew")
    check(restored.workforce_capacity() == before - 4, "Restored crew must remain excluded from civilian jobs")
    check(is_equal_approx(float(restored.outposts[0].road), 1), "JSON snapshot must restore road")
    check(is_equal_approx(float(restored.outposts[0].route_progress), float(post.route_progress)), "JSON snapshot must restore trip progress")
    post.enabled = false
    progress(sim, 50)
    check(post.leg == "Home", "Pausing must finish the current carrier trip")
    var delivered: float = post.delivered
    progress(sim, 5)
    check(post.delivered == delivered and post.leg == "Home", "Paused route must not dispatch another trip")
    var reserve: float = post.reserve
    Logistics.order(sim, "recall_outpost", [0])
    progress(sim, 60)
    check(sim.outposts.is_empty() and sim.workforce_capacity() == before, "Recall must return crew to workforce")
    Logistics.order(sim, "found_outpost", [0])
    check(sim.outposts[0].reserve == reserve and sim.outposts[0].road == 1, "Re-founding must preserve depleted reserve and road")
    Logistics.order(sim, "recall_outpost", [0])
    progress(sim, 1)
    check(sim.outposts.is_empty(), "Recall at departure must not complete the outbound journey")
    var overflow = settlement()
    Logistics.order(overflow, "found_outpost", [0])
    var held: Dictionary = overflow.outposts[0]
    held.stage = "Working"
    held.leg = "Inbound"
    held.route_progress = 0.9999
    held.cargo = 8.0
    overflow.resources = {"food": overflow.capacity(), "wood": 0.0, "stone": 0.0}
    progress(overflow, 0.25)
    check(held.cargo == 8 and held.leg == "Home", "Full town storage must retain delivery cargo")
    overflow.resources.food -= 16
    progress(overflow, 0.25)
    check(held.cargo == 0 and overflow.resources.stone == 8, "Carrier must unload after storage space opens")
    var hungry = settlement()
    Logistics.order(hungry, "found_outpost", [1])
    hungry.outposts[0].food = 0.0
    progress(hungry, 4)
    check(hungry.outposts.is_empty() or hungry.outposts[0].stage == "Returning", "Hungry founding party must turn back")
    var retired = settlement()
    Logistics.order(retired, "found_outpost", [0])
    var retired_id: int = retired.outposts[0].units[0]
    for person in retired.people:
        if int(person.id) == retired_id: person.age = 65
    progress(retired, 1)
    check(retired.outposts.is_empty(), "Retirement on departure must safely recall the party")
    var winter = settlement()
    Logistics.order(winter, "found_outpost", [2])
    winter.day = 280
    winter.outposts[0].stage = "Working"
    winter.outposts[0].enabled = false
    progress(winter, 2)
    check(winter.outposts[0].stock == 0, "Meadow production must stop in winter")
    var session = Session.new()
    var host_sim = settlement()
    var rival_sim = settlement()
    rival_sim.world_origin = [-25.0, -22.0]
    session.civilizations = {"host": {"sim": host_sim}, "rival": {"sim": rival_sim}}
    check(session.player_command("host", "found_outpost", [0]).contains("too close"), "Host must reject founding beside a rival town")
    check(host_sim.outposts.is_empty(), "Rejected host command must not spend a crew")
    check(session.apply_command(host_sim, "found_outpost", [-1]) == "Choose a resource site.", "Command must reject invalid site index")
    check(session.apply_command(host_sim, "outpost_road", []).contains("Choose"), "Command must reject malformed road order")
    session.free()
    var save_path := OS.get_temp_dir().path_join("civilization-outpost-check-%d.json" % Time.get_ticks_usec())
    sim.save_path = save_path
    sim.save_game()
    var loaded = Simulation.new()
    loaded.save_path = save_path
    loaded.load_game()
    check(loaded.outpost_sites.has("0") and loaded.outpost_sites["0"].road == 1, "Disk save/load must retain road after recall")
    DirAccess.remove_absolute(save_path)
    sim.save_path = ""
    var legacy: Dictionary = sim.snapshot()
    legacy.erase("outposts")
    legacy.erase("outpost_sites")
    restored.restore_snapshot(legacy)
    check(restored.outposts.is_empty() and restored.outpost_sites.is_empty(), "Legacy snapshots must clear remote state")
    print("Outpost checks: %d passed, %d failed" % [checks - failures, failures])
    quit(1 if failures else 0)
