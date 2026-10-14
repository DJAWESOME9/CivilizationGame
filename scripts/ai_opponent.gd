extends RefCounted

const Warfare = preload("res://scripts/warfare.gd")
const DIFFICULTIES = {
    "Easy": {"interval": 12.0, "peace_days": 720.0, "raid_interval": 360.0, "soldiers": 4},
    "Normal": {"interval": 6.0, "peace_days": 540.0, "raid_interval": 180.0, "soldiers": 6},
    "Hard": {"interval": 2.0, "peace_days": 360.0, "raid_interval": 90.0, "soldiers": 8}
}
const RESEARCH = ["Toolmaking", "Fishing", "Woodcutting", "Shelter Building", "Stoneworking", "Storage", "Basketry", "Hunting", "Scouting", "Planting", "Preservation", "Carpentry", "Sanitation", "Forestry", "Education", "Masonry", "Crop Rotation", "Waterworks"]

static func decide(session, token: String) -> void:
    var record: Dictionary = session.civilizations[token]
    if session.world_day < float(record.get("next_decision", 0)): return
    var spec: Dictionary = DIFFICULTIES.get(record.get("difficulty", "Normal"), DIFFICULTIES.Normal)
    record.next_decision = session.world_day + spec.interval
    var sim = record.sim
    # No extra resources or production bonuses: every order uses normal validation.
    sim.emergency_food = true
    if sim.research.is_empty():
        for tech in RESEARCH:
            if tech not in sim.technologies and sim.research_block(tech).is_empty():
                sim.choose_research(tech)
                break
    manage_buildings(sim)
    allocate_workers(sim)
    sim.defense_order = "Preserve people" if record.difficulty == "Easy" else "Counterattack"
    if sim.resources.food > sim.population * 0.5:
        var military_goal := int(spec.soldiers) * (2 if record.difficulty == "Hard" else 1)
        if sim.military_ids().size() < military_goal and sim.workforce_capacity() > 14:
            for commander in ["None"]:
                var unit := "Spearmen" if "Stoneworking" in sim.technologies else "Militia"
                var count := mini(int(spec.soldiers), military_goal - sim.military_ids().size())
                if Warfare.recruit_block(sim, unit, count, commander).is_empty():
                    Warfare.recruit(sim, unit, count, commander)
                    break
        scout(session, token)
    for pool in sim.armies.duplicate():
        if pool.get("reserve", false) and pool.status == "Ready":
            var new_id: int = sim.next_army_id
            Warfare.army_order(sim, "create_army", [pool.unit, pool.soldiers.size(), "Home guard"])
            Warfare.army_order(sim, "assign_defense", [new_id, true])
    for offer in session.trade_offers.duplicate():
        if offer.to != token: continue
        # Accept fair exchanges only when payment leaves a food reserve.
        var reserve: float = sim.population * 0.5 if offer.ask == "food" else 0.0
        var fair: bool = offer.give_amount >= offer.ask_amount and sim.resources[offer.ask] - offer.ask_amount >= reserve
        session.player_command(token, "accept_trade" if fair else "decline_trade", [int(offer.id)])
        # If capacity or the sender's stock changed, dismiss the failed offer.
        if offer in session.trade_offers: session.player_command(token, "decline_trade", [int(offer.id)])
    if session.world_day >= float(record.get("next_raid", spec.peace_days)) and sim.resources.food > sim.population:
        for army in sim.armies:
            if army.status != "Ready" or army.morale < 80: continue
            for known in sim.known_civilizations.values():
                var before: int = session.warfare.next_campaign
                session.warfare.launch(session, token, int(army.id), int(known.slot))
                if session.warfare.next_campaign != before:
                    session.votes.clear()
                    record.next_raid = session.world_day + spec.raid_interval
                    return

static func manage_buildings(sim) -> void:
    for building in sim.buildings:
        if building.progress < 1: return
    var desired := ""
    if sim.completed("House") == 0 or sim.housing() <= sim.population + 2: desired = "House"
    elif sim.completed("Storehouse") == 0: desired = "Storehouse"
    elif sim.completed("Training Grounds") == 0: desired = "Training Grounds"
    elif sim.completed("Barracks") == 0: desired = "Barracks"
    elif sim.completed("Field") == 0: desired = "Field"
    elif sim.completed("Well") == 0: desired = "Well"
    elif sim.completed("Palisade") == 0: desired = "Palisade"
    elif sim.completed("School") == 0: desired = "School"
    elif "Masonry" in sim.technologies and sim.completed("Wall") == 0: desired = "Wall"
    if desired.is_empty() or not sim.building_block(desired).is_empty(): return
    for q in range(-5, 3):
        for r in range(-5, 6):
            if sim.order_build(desired, q, r).is_empty(): return

static func allocate_workers(sim) -> void:
    sim.automatic_workforce = false
    for job in sim.JOBS: sim.assignments[job] = 0
    var available: int = sim.workforce_capacity()
    var fishing: bool = sim.job_unlocked("Fishing")
    var food_job := "Fishing" if fishing else "Gathering"
    var food_workers := mini(available, maxi(6, ceili(sim.population * (0.40 if fishing else 0.55))))
    if sim.resources.food < sim.population * 0.5: food_workers = mini(available, maxi(food_workers, ceili(available * 0.75)))
    sim.assignments[food_job] = food_workers
    available -= food_workers
    var building := false
    for site in sim.buildings:
        if site.progress < 1: building = true
    for job in ["Construction", "Logging", "Quarrying", "Farming"]:
        if not sim.job_unlocked(job): continue
        var count := 0
        if job == "Construction" and building: count = mini(4, available)
        elif job == "Logging" and sim.resources.wood < 65: count = mini(5, available)
        elif job == "Quarrying" and sim.resources.stone < 45: count = mini(4, available)
        elif job == "Farming" and sim.completed("Field") > 0: count = mini(3, available)
        sim.assignments[job] = count
        available -= count
    sim.assignments[food_job] += available
    sim.clamp_assignments()
    sim.prepare_roster(sim.effective_assignments())

static func scout(session, token: String) -> void:
    var sim = session.civilizations[token].sim
    if "Scouting" not in sim.technologies or not sim.scouting_units().is_empty() or sim.workforce_capacity() < 12: return
    var origin := Vector2(sim.world_origin[0], sim.world_origin[1])
    for other in session.civilizations:
        var slot: int = session.civilizations[other].slot
        if other == token or sim.known_civilizations.has(str(slot)): continue
        sim.send_scouts(Warfare.SITES[slot] - origin)
        return
