extends SceneTree

var failures := 0

func _initialize() -> void:
    call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func run_checks() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    var session = scene.session
    session.set_process(false)
    session.world_save_path = "/tmp/civilization_ai_test.json"
    var ui = scene.multiplayer_screen
    ui.resume_world.button_pressed = false
    ui.refresh()
    check(ui.ai_count.editable and not ui.ai_difficulty.disabled, "Fresh worlds allow AI configuration")
    session.host_game("Tester", 25439, 8640.0, false, 3, "Hard")
    check(session.active and session.civilizations.size() == 4, "Host creates three opponents")
    if not session.active:
        quit(1)
        return
    check(session.roster.filter(func(p): return p.get("ai", false)).size() == 3, "Roster distinguishes AI")
    var before: float = session.world_day
    session.vote_fast_forward()
    check(session.world_day > before and session.votes.is_empty(), "AI does not block human fast-forward")
    session.advance_world(1000)
    var army_count := 0
    for record in session.civilizations.values():
        if not record.get("ai", false): continue
        print(record.name, " day ", session.world_day, " population ", record.sim.population, " techs ", record.sim.technologies.size(), " buildings ", record.sim.buildings.size(), " armies ", record.sim.armies.size(), " contacts ", record.sim.known_civilizations.size())
        check(record.sim.technologies.size() >= 10, "AI researches independently")
        check(record.sim.completed("Barracks") > 0, "AI develops military infrastructure")
        check(not record.sim.known_civilizations.is_empty(), "AI scouts actual rivals")
        check(record.sim.population > 0, "AI survives")
        army_count += record.sim.armies.size()
    check(army_count > 0 and session.warfare.next_campaign > 1, "AI trains armies and launches raids")
    var bot = session.civilizations.ai_0
    var human = session.civilizations[session.own_token].sim
    human.known_civilizations[str(bot.slot)] = {"slot": bot.slot, "point": [-4.0, 56.0], "name": bot.name, "last_seen": session.world_day, "population": bot.sim.population, "buildings": []}
    human.resources = {"food": 20.0, "wood": 20.0, "stone": 20.0}
    bot.sim.resources = {"food": 50.0, "wood": 20.0, "stone": 20.0}
    session.player_command(session.own_token, "offer_trade", [int(bot.slot), "wood", 5, "stone", 5])
    bot.next_decision = session.world_day
    preload("res://scripts/ai_opponent.gd").decide(session, "ai_0")
    check(session.trade_offers.is_empty() and human.resources.stone == 25.0, "AI accepts fair affordable barter")
    session.persist()
    var saved_decision: float = bot.next_decision
    var saved_day: float = session.world_day
    session.leave()
    session.host_game("Tester", 25439, -1.0, true, 0, "Easy")
    check(session.civilizations.size() == 4 and session.civilizations.ai_0.difficulty == "Hard", "Resume preserves count and difficulty")
    check(session.civilizations.ai_0.next_decision == saved_decision and session.world_day == saved_day, "Resume preserves AI timers without testing catch-up")
    ui.resume_world.button_pressed = true
    ui.refresh()
    check(not ui.ai_count.editable and ui.ai_difficulty.disabled, "Resume locks saved AI choices")
    session.leave()
    session.host_game("Tester", 25439, 8640.0, false, 0, "Normal")
    check(session.civilizations.size() == 1, "Zero AI remains supported")
    session.leave()
    for difficulty in ["Easy", "Normal"]:
        session.host_game("Tester", 25439, 8640.0, false, 1, difficulty)
        session.advance_world(1000)
        var opponent = session.civilizations.ai_0.sim
        check(opponent.population > 0 and opponent.completed("Barracks") > 0 and not opponent.known_civilizations.is_empty(), difficulty + " opponent develops and scouts")
        print(difficulty, " population ", opponent.population, " armies ", opponent.armies.size(), " campaigns ", session.warfare.next_campaign - 1)
        session.leave()
    DirAccess.remove_absolute(session.world_save_path)
    print("AI world checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
    quit(0 if failures == 0 else 1)
