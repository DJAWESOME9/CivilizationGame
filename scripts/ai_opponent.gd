extends RefCounted

const Warfare = preload("res://scripts/warfare.gd")
const DIFFICULTIES = {
    "Easy": {"interval": 12.0, "peace_days": 720.0, "raid_interval": 360.0, "soldiers": 4},
    "Normal": {"interval": 6.0, "peace_days": 540.0, "raid_interval": 180.0, "soldiers": 6},
    "Hard": {"interval": 2.0, "peace_days": 360.0, "raid_interval": 90.0, "soldiers": 8}
}
const RESEARCH = ["Toolmaking", "Fishing", "Woodcutting", "Shelter Building", "Community Organization", "Military Organization", "Stoneworking", "Storage", "Basketry", "Hunting", "Scouting", "Planting", "Preservation", "Carpentry", "Sanitation", "Forestry", "Education", "Masonry", "Crop Rotation", "Waterworks", "Pottery", "Boatbuilding", "Archery", "Writing", "River Navigation", "Joinery"]

static func decide(session, token: String) -> void:
    var record: Dictionary = session.civilizations[token]
    if session.world_day < float(record.get("next_decision", 0)): return
    var spec: Dictionary = DIFFICULTIES.get(record.get("difficulty", "Normal"), DIFFICULTIES.Normal)
    record.next_decision = session.world_day + spec.interval
    var sim = record.sim
    for item in session.warfare.passage_items(session, token):
        if item.incoming:
            var requester := ""
            for campaign in session.warfare.campaigns:
                if int(campaign.id) == int(item.campaign): requester = str(campaign.attacker)
            var allow: bool = not requester.is_empty() and int(session.relationship(token, requester).score) > -20
            session.player_command(token, "passage_reply", [int(item.campaign), int(item.request), allow])
        else:
            # Hard AI may escalate; easier opponents wait for new opportunities.
            session.player_command(token, "passage_attack" if record.difficulty == "Hard" else "passage_wait", [int(item.campaign), int(item.request)])
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
    # Hostile civilizations can also stop ordinary scouts with their home armies.
    if not session.ready_scout_guard(token).is_empty():
        for party in session.visiting_scouts(token):
            if party.trade: continue
            var other := ""
            for candidate in session.civilizations:
                if int(session.civilizations[candidate].slot) == int(party.slot): other = candidate
            if not other.is_empty() and int(session.relationship(token, other).score) <= -20 and randf() < 0.15:
                session.kill_visiting_scouts(token, int(party.slot), float(party.started), party.units)
    for offer in session.trade_offers.duplicate():
        if offer.to != token or offer.get("stage", "") != "Awaiting decision": continue
        var reserve: float = sim.population * 0.5 if offer.ask == "food" else 0.0
        var value_received: float = offer.give_amount * resource_need(sim, offer.give)
        var value_paid: float = offer.ask_amount * resource_need(sim, offer.ask)
        var fair: bool = offer.give != offer.ask and value_received >= value_paid and sim.resources[offer.ask] - offer.ask_amount >= reserve
        var chance: float = float(session.relationship(token, str(offer.from)).chance) * clampf(value_received / maxf(1.0, value_paid), 0.25, 1.5)
        var hostile: bool = int(session.relationship(token, str(offer.from)).score) <= -20
        var decision := "seize_trade" if hostile and randf() < 0.15 else ("accept_trade" if fair and randf() * 100 < chance else "decline_trade")
        session.player_command(token, decision, [int(offer.id)])
        if offer in session.trade_offers: session.player_command(token, "decline_trade", [int(offer.id)])
    if session.world_day >= float(record.get("next_trade", 0)):
        record.next_trade = session.world_day + 30.0
        var needed := "food"
        var surplus := "wood"
        for resource in ["food", "wood", "stone"]:
            if resource_need(sim, resource) > resource_need(sim, needed): needed = resource
            if resource_need(sim, resource) < resource_need(sim, surplus): surplus = resource
        if needed != surplus and resource_need(sim, needed) > 1.0 and sim.resources[surplus] >= 20:
            for contact in sim.known_civilizations.values():
                session.player_command(token, "offer_trade", [int(contact.slot), surplus, 10, needed, 10])
                break
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
    elif "Pottery" in sim.technologies and sim.completed("Pottery Workshop") == 0: desired = "Pottery Workshop"
    elif "Boatbuilding" in sim.technologies and sim.completed("Boatyard") == 0: desired = "Boatyard"
    elif "Writing" in sim.technologies and sim.completed("Archive") == 0: desired = "Archive"
    elif "Joinery" in sim.technologies and sim.completed("Carpenter Workshop") == 0: desired = "Carpenter Workshop"
    elif "Waterworks" in sim.technologies and sim.completed("Bathhouse") == 0: desired = "Bathhouse"
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

static func resource_need(sim, resource: String) -> float:
    var target: float = maxf(15.0, float(sim.population)) if resource == "food" else (65.0 if resource == "wood" else 45.0)
    return clampf(target / maxf(1.0, float(sim.resources[resource])), 0.25, 4.0)
