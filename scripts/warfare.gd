extends RefCounted

const UNITS = {
    "Militia": {"attack": 1.0, "defense": 0.8, "wood": 1.0, "stone": 0.0, "days": 10.0, "tech": "Toolmaking"},
    "Spearmen": {"attack": 1.5, "defense": 1.8, "wood": 2.0, "stone": 1.0, "days": 20.0, "tech": "Stoneworking"},
    "Archers": {"attack": 1.8, "defense": 0.9, "wood": 3.0, "stone": 1.0, "days": 30.0, "tech": "Archery"}
}
const COMMANDERS = {
    "None": {"style": "None", "attack": 1.0, "defense": 1.0, "description": "No commander · no abilities or command bonuses."},
    "Aren": {"style": "Steadfast", "attack": 1.0, "defense": 1.20, "description": "Shield discipline: +20% defense."},
    "Mira": {"style": "Swift", "attack": 1.15, "defense": 1.0, "description": "Rapid maneuver: +15% attack; marches 20% faster."},
    "Tovan": {"style": "Careful", "attack": 1.05, "defense": 1.10, "description": "Measured leadership: +5% attack, +10% defense; less morale lost on withdrawal."}
}
const TACTICS = ["Advance", "Hold ground", "Flank", "Skirmish"]
const FORMATIONS = ["Line", "Shield wall", "Loose"]
const DEFENSES = ["Hold settlement", "Counterattack", "Preserve people"]
# Keep the original eight slots stable for saved worlds. All sites remain on
# the western bank and within scouting range from every starting region.
const SITES = [Vector2(-32, -28), Vector2(-32, 28), Vector2(-88, -28), Vector2(-88, 28), Vector2(-32, 0), Vector2(-88, 0), Vector2(-60, -44), Vector2(-60, 44), Vector2(-16, -36), Vector2(-16, -12), Vector2(-16, 12), Vector2(-16, 36), Vector2(-60, -24), Vector2(-60, 0), Vector2(-60, 24), Vector2(-88, -44)]
var campaigns: Array = []
var next_campaign := 1
var revision := 0

static func find_army(simulation, army_id: int) -> Dictionary:
    for army in simulation.armies:
        if int(army.id) == army_id: return army
    return {}

static func recruit_block(simulation, unit: String, count: int, commander: String) -> String:
    if not UNITS.has(unit) or not COMMANDERS.has(commander): return "Choose a unit type and commander."
    if commander != "None" and commander not in available_commanders(simulation): return "That commander has not been acquired."
    if count < 1 or count > 30: return "Recruit between 1 and 30 soldiers per group."
    var spec: Dictionary = UNITS[unit]
    if spec.tech not in simulation.technologies: return "Requires " + spec.tech + "."
    if simulation.completed("Training Grounds") == 0: return "Build training grounds before training soldiers."
    var housing_used := 0
    for army in simulation.armies: housing_used += army.soldiers.size()
    if housing_used + count > simulation.military_capacity(): return "Not enough military housing. Each completed barracks supports 12 soldiers."
    for army in simulation.armies:
        if commander != "None" and army.commander == commander: return "This commander already leads a group."
    var available := 0
    for person in simulation.people:
        if person.age >= 16 and person.age < 65 and not simulation.on_birth_leave(person) and not simulation.is_pregnant(person) and person.training.is_empty() and int(person.id) not in simulation.military_ids() and int(person.id) not in simulation.scouting_units(): available += 1
    if count > available - 3: return "Keep at least three available civilians; there are not enough recruits."
    if simulation.resources.wood < spec.wood * count or simulation.resources.stone < spec.stone * count: return "Not enough wood or stone for their equipment."
    return ""

static func recruit(simulation, unit: String, count: int, commander: String) -> String:
    var blocked := recruit_block(simulation, unit, count, commander)
    if not blocked.is_empty(): return blocked
    var soldiers: Array = []
    var reserved: Array = simulation.military_ids()
    for person in simulation.people:
        if person.age >= 16 and person.age < 65 and not simulation.on_birth_leave(person) and not simulation.is_pregnant(person) and person.training.is_empty() and int(person.id) not in reserved and int(person.id) not in simulation.scouting_units():
            soldiers.append(int(person.id))
            if soldiers.size() == count: break
    var spec: Dictionary = UNITS[unit]
    simulation.resources.wood -= spec.wood * count
    simulation.resources.stone -= spec.stone * count
    simulation.armies.append({"id": simulation.next_army_id, "unit": unit, "soldiers": soldiers, "commander": commander, "status": "Training", "training": 0.0, "morale": 100.0, "experience": 0.0, "tactic": "Hold ground", "formation": "Line", "autonomy": commander != "None", "reserve": true, "defend_home": false, "name": "Training intake", "retreat": 35, "supplies": 0.0, "cargo": {"food": 0.0, "wood": 0.0, "stone": 0.0}})
    simulation.next_army_id += 1
    simulation.clamp_assignments()
    simulation.prepare_roster(simulation.effective_assignments())
    simulation.announce("%d %s began training; they have left civilian duties." % [count, unit.to_lower()])
    return "Training commissioned; equipment paid up front."

static func army_order(simulation, action: String, args: Array) -> String:
    if action == "recruit":
        if args.size() != 3 or not args[0] is String or not args[1] is int or not args[2] is String: return "Invalid recruitment order."
        return recruit(simulation, args[0], args[1], args[2])
    if action == "create_army":
        if args.size() != 3 or args[0] not in UNITS or not args[1] is int or not args[2] is String: return "Choose a unit, count and army name."
        var count: int = args[1]
        if count < 1 or count > 30: return "Choose 1–30 trained soldiers."
        var ready: Array = []
        for pool in simulation.armies:
            if pool.get("reserve", false) and pool.status == "Ready" and pool.unit == args[0]: ready.append_array(pool.soldiers)
        if ready.size() < count: return "Not enough fully trained, unassigned units."
        ready.resize(count)
        var morale := 100.0
        var experience := 1.0
        for pool in simulation.armies:
            if pool.get("reserve", false):
                for id in ready:
                    if id in pool.soldiers:
                        morale = minf(morale, float(pool.morale))
                        experience = minf(experience, float(pool.experience))
                        pool.soldiers.erase(id)
        var group := {"id": simulation.next_army_id, "name": args[2].strip_edges().left(32), "unit": args[0], "soldiers": ready, "commander": "None", "status": "Ready", "training": UNITS[args[0]].days, "morale": morale, "experience": experience, "tactic": "Hold ground", "formation": "Line", "autonomy": false, "retreat": 35, "supplies": 0.0, "cargo": {"food": 0.0, "wood": 0.0, "stone": 0.0}, "reserve": false, "defend_home": false}
        if group.name.is_empty(): group.name = "Army %d" % simulation.next_army_id
        simulation.next_army_id += 1
        simulation.armies.append(group)
        simulation.advance_armies(0)
        return "Army created from fully trained reserves."
    if action == "defense":
        if args.size() != 1 or args[0] not in DEFENSES: return "Invalid defense order."
        simulation.defense_order = args[0]
        simulation.announce("Standing defense order: " + args[0] + ".")
        return "Standing defense order saved; it also applies while you are offline."
    if args.is_empty() or not args[0] is int: return "Choose an army."
    var army := find_army(simulation, args[0])
    if army.is_empty(): return "That army no longer exists."
    if action == "resize_army":
        if args.size() != 2 or not args[1] is int or args[1] < 1 or args[1] > 30: return "Choose 1–30 soldiers."
        if army.status != "Ready" or army.get("reserve", false): return "Edit a ready army at home."
        var difference: int = int(args[1]) - army.soldiers.size()
        if difference > 0:
            var available: Array = []
            for pool in simulation.armies:
                if pool.get("reserve", false) and pool.status == "Ready" and pool.unit == army.unit: available.append_array(pool.soldiers)
            if available.size() < difference: return "Not enough fully trained reserves of this unit type."
            available.resize(difference)
            for pool in simulation.armies:
                if not pool.get("reserve", false): continue
                for id in available:
                    if id in pool.soldiers:
                        army.morale = minf(float(army.morale), float(pool.morale))
                        army.experience = minf(float(army.experience), float(pool.experience))
                        pool.soldiers.erase(id)
            army.soldiers.append_array(available)
        elif difference < 0:
            var pool: Dictionary = army.duplicate(true)
            pool.id = simulation.next_army_id
            simulation.next_army_id += 1
            pool.soldiers = army.soldiers.slice(int(args[1]))
            army.soldiers.resize(int(args[1]))
            pool.reserve = true
            pool.defend_home = false
            pool.commander = "None"
            pool.autonomy = false
            pool.name = "Trained reserves"
            simulation.armies.append(pool)
        simulation.advance_armies(0)
        return "Army composition updated using fully trained reserves."
    if action == "reserve_army":
        if army.status != "Ready" or army.get("reserve", false): return "Return a ready army at home to reserves."
        army.reserve = true
        army.defend_home = false
        army.commander = "None"
        army.autonomy = false
        army.name = "Trained reserves"
        return "Soldiers returned to trained reserves; create a new army to reorganize them."
    if action == "rename_army":
        if args.size() != 2 or not args[1] is String or args[1].strip_edges().is_empty(): return "Enter an army name."
        if army.status not in ["Ready", "Recovering"] or army.get("reserve", false): return "Edit formed armies at home."
        army.name = args[1].strip_edges().left(32)
        return "Army renamed."
    if action == "assign_defense":
        if args.size() != 2 or not args[1] is bool: return "Choose a defense assignment."
        if army.status not in ["Ready", "Recovering"] or army.get("reserve", false): return "Assign a formed army currently at home."
        army.defend_home = args[1]
        return "Army assigned to defend home." if args[1] else "Army released from home defense."
    if action == "appoint":
        if args.size() != 2 or args[1] not in COMMANDERS: return "Choose a commander."
        if args[1] != "None" and args[1] not in available_commanders(simulation): return "That commander has not been acquired."
        if army.status not in ["Ready", "Training", "Recovering"]: return "Reassign commanders while the army is home."
        for other in simulation.armies:
            if args[1] != "None" and other.id != army.id and other.commander == args[1]: return "That commander already leads another group."
        army.commander = args[1]
        if army.commander == "None": army.autonomy = false
        return "Commander reassigned."
    if action == "disband":
        if army.status not in ["Ready", "Training", "Recovering"]: return "Recall the army and wait for it to return first."
        simulation.armies.erase(army)
        if simulation.automatic_workforce: simulation.apply_targets()
        else: simulation.clamp_assignments()
        return "Soldiers returned to the civilian workforce; spent equipment is not refunded."
    if action == "army_plan":
        if args.size() != 5 or args[1] not in TACTICS or args[2] not in FORMATIONS or not args[3] is bool or not args[4] is int: return "Invalid battle plan."
        army.tactic = args[1]
        army.formation = args[2]
        army.autonomy = args[3] and army.commander != "None"
        army.retreat = clampi(args[4], 15, 70)
        return "Commander orders updated."
    return "Unknown military order."

func launch(session, token: String, army_id: int, target_slot: int, mission: String = "Raid") -> String:
    var attacker = session.civilizations[token].sim
    var army := find_army(attacker, army_id)
    if army.is_empty() or army.status != "Ready" or army.get("reserve", false): return "Choose a trained army at home."
    if army.morale < 60: return "The army needs to recover to at least 60 morale before marching."
    if "Scouting" not in attacker.technologies: return "Research Scouting before sending an army to another civilization."
    var target := ""
    for candidate in session.civilizations:
        if int(session.civilizations[candidate].slot) == target_slot: target = candidate
    if target.is_empty() or target == token: return "Choose another civilization."
    if not attacker.known_civilizations.has(str(target_slot)): return "Send scouts to discover that civilization first."
    var travel: float = SITES[int(session.civilizations[token].slot)].distance_to(SITES[target_slot]) / 3.0
    if army.commander == "Mira": travel /= 1.2
    var food := ceilf(army.soldiers.size() * (travel * 2.0 / 0.65 + 16.0) / 90.0 * 1.5)
    if attacker.resources.food < food: return "The expedition needs %.0f food for travel, fighting and return." % food
    attacker.resources.food -= food
    army.supplies = food
    army.status = "Marching"
    army.defend_home = false
    campaigns.append({"id": next_campaign, "attacker": token, "defender": target, "army": army_id, "mission": mission, "messengers": [], "phase": "Marching", "elapsed": 0.0, "travel": travel, "round_clock": 0.0, "rounds": 0, "attacker_losses": 0, "defender_losses": 0, "defender_armies": [], "attacker_start": army.soldiers.size(), "defender_start": 0, "militia": [], "militia_morale": 65.0, "result": "", "loot": {"food": 0.0, "wood": 0.0, "stone": 0.0}, "from_slot": session.civilizations[token].slot, "to_slot": target_slot})
    next_campaign += 1
    attacker.announce("%s marches with %d %s to %s %s." % [army_name(army), army.soldiers.size(), army.unit.to_lower(), mission.to_lower(), session.civilizations[target].name])
    # Defenders discover approaching armies through actual sight, not launch notifications.
    revision += 1
    return "Army dispatched; provisions reserved. Your target can be offline."

func recall(session, token: String, army_id: int) -> String:
    return send_messenger(session, token, army_id, "Return")

static func available_commanders(simulation) -> Array:
    var result: Array = ["None"]
    for chief in simulation.owned_commanders:
        if chief in COMMANDERS and chief not in result: result.append(chief)
    for army in simulation.armies:
        if army.commander != "None" and army.commander not in result: result.append(army.commander)
    return result

static func army_name(army: Dictionary) -> String:
    return army.get("name", "Army %d" % int(army.id))

func send_messenger(session, token: String, army_id: int, order: String, payload: Array = []) -> String:
    if order not in ["Hold", "Return", "Raid", "Attack", "Plan"]: return "Invalid messenger order."
    var sim = session.civilizations[token].sim
    if order in ["Raid", "Attack"]:
        if payload.size() != 1 or not payload[0] is int or not sim.known_civilizations.has(str(payload[0])): return "Choose a discovered civilization."
        if payload[0] == int(session.civilizations[token].slot): return "Choose another civilization."
    if order == "Plan" and (payload.size() != 4 or payload[0] not in TACTICS or payload[1] not in FORMATIONS or not payload[2] is bool or not payload[3] is int): return "Invalid battle plan."
    for campaign in campaigns:
        if campaign.attacker != token or int(campaign.army) != army_id: continue
        if campaign.phase not in ["Marching", "Holding", "Returning", "Fighting", "Raiding"]: continue
        if not campaign.get("messengers", []).is_empty(): return "A messenger is already carrying orders to this army."
        var origin: Vector2 = SITES[int(session.civilizations[token].slot)]
        campaign.messengers = [{"point": [origin.x, origin.y], "order": order, "payload": payload.duplicate(true)}]
        revision += 1
        return "Messenger dispatched at three times army speed. Current orders continue until delivery."
    return "That army is no longer in the field."

func deliver_message(session, campaign: Dictionary, message: Dictionary) -> void:
    var sim = session.civilizations[campaign.attacker].sim
    var army := find_army(sim, int(campaign.army))
    if army.is_empty(): return
    var point := campaign_point(campaign)
    if message.order == "Plan":
        army_order(sim, "army_plan", [int(army.id)] + message.payload)
    elif message.order == "Return":
        release_defenders(session, campaign)
        campaign.return_point = [point.x, point.y]
        campaign.return_days = maxf(0.05, point.distance_to(SITES[int(campaign.from_slot)]) / march_speed(army))
        campaign.elapsed = 0.0
        campaign.phase = "Returning"
        army.status = "Returning"
    elif message.order == "Hold":
        release_defenders(session, campaign)
        campaign.hold_point = [point.x, point.y]
        campaign.phase = "Holding"
        army.status = "Holding"
    else:
        var target_token := ""
        for candidate in session.civilizations:
            if int(session.civilizations[candidate].slot) == int(message.payload[0]): target_token = candidate
        if target_token.is_empty(): return
        release_defenders(session, campaign)
        campaign.defender = target_token
        campaign.to_slot = int(message.payload[0])
        campaign.route_start = [point.x, point.y]
        campaign.travel = maxf(0.05, point.distance_to(SITES[int(campaign.to_slot)]) / march_speed(army))
        campaign.elapsed = 0.0
        campaign.phase = "Marching"
        campaign.mission = message.order
        campaign.rounds = 0
        campaign.round_clock = 0.0
        campaign.defender_armies = []
        campaign.militia = []
        campaign.defender_start = 0
        campaign.militia_morale = 65.0
        campaign.attacker_losses = 0
        campaign.defender_losses = 0
        campaign.militia_losses = 0
        army.status = "Marching"
    sim.announce("Messenger reached %s: %s orders delivered." % [army_name(army), message.order])
    revision += 1

static func march_speed(army: Dictionary) -> float:
    return 3.6 if army.commander == "Mira" else 3.0

func advance(session, days: float) -> void:
    var remaining := days
    while remaining > 0.000001:
        var step := minf(remaining, 0.1)
        advance_step(session, step)
        remaining -= step

func advance_step(session, days: float) -> void:
    for campaign in campaigns.duplicate():
        var sim = session.civilizations[campaign.attacker].sim
        var army := find_army(sim, int(campaign.army))
        if army.is_empty():
            finish(session, campaign, false, "The expedition has no active soldiers remaining.")
            release_defenders(session, campaign)
            campaigns.erase(campaign)
            revision += 1
            continue
        for message in campaign.get("messengers", []).duplicate():
            var courier := Vector2(message.point[0], message.point[1])
            var destination := campaign_point(campaign)
            var distance: float = 9.0 * sim.travel_factor() * days
            if courier.distance_to(destination) <= distance:
                campaign.messengers.erase(message)
                deliver_message(session, campaign, message)
            else:
                courier = courier.move_toward(destination, distance)
                message.point = [courier.x, courier.y]
        var defender = session.civilizations[campaign.defender].sim
        var living_ids: Array = []
        for person in defender.people: living_ids.append(int(person.id))
        for id in campaign.militia.duplicate():
            if int(id) not in living_ids: campaign.militia.erase(id)
        army.supplies = maxf(0, float(army.supplies) - army.soldiers.size() / 90.0 * 1.5 * days)
        if army.supplies <= 0: army.morale = maxf(0, float(army.morale) - days * 6)
        campaign.elapsed += days * sim.travel_factor() if campaign.phase in ["Marching", "Returning"] else days
        if campaign.phase == "Marching" and campaign.elapsed >= campaign.travel:
            begin_battle(session, campaign)
        elif campaign.phase == "Fighting":
            campaign.round_clock += days
            while campaign.round_clock >= 1.0 and campaign.phase == "Fighting":
                campaign.round_clock -= 1.0
                resolve_round(session, campaign)
        elif campaign.phase == "Raiding" and campaign.elapsed >= 1.0:
            campaign.phase = "Returning"
            campaign.elapsed = 0.0
            army.status = "Returning"
            revision += 1
        elif campaign.phase == "Returning" and campaign.elapsed >= campaign.get("return_days", campaign.travel):
            army.status = "Recovering" if army.morale < 60 else "Ready"
            for resource in army.cargo:
                var spare := maxf(0, sim.capacity() - sim.resources.food - sim.resources.wood - sim.resources.stone)
                sim.resources[resource] += minf(float(army.cargo[resource]), spare)
            var spare := maxf(0, sim.capacity() - sim.resources.food - sim.resources.wood - sim.resources.stone)
            sim.resources.food += minf(float(army.supplies), spare)
            army.supplies = 0.0
            army.cargo = {"food": 0.0, "wood": 0.0, "stone": 0.0}
            sim.announce("%s's surviving soldiers returned; supplies and plunder were stored where space allowed." % army.commander)
            campaigns.erase(campaign)
            revision += 1

func begin_battle(session, campaign: Dictionary) -> void:
    campaign.phase = "Fighting"
    campaign.elapsed = 0.0
    var attacker = session.civilizations[campaign.attacker].sim
    var defender = session.civilizations[campaign.defender].sim
    var army := find_army(attacker, int(campaign.army))
    army.status = "Fighting"
    for group in defender.armies:
        if group.status == "Ready" and not group.get("reserve", false) and group.get("defend_home", true):
            group.status = "Defending"
            campaign.defender_armies.append(int(group.id))
            campaign.defender_start += group.soldiers.size()
    # Emergency militia use actual available adults, including those working civilian jobs.
    if campaign.defender_armies.is_empty() and defender.defense_order != "Preserve people" and defender.workforce_capacity() > 3:
        var available: Array = defender.military_ids() + defender.scouting_units()
        for person in defender.people:
            if person.age >= 16 and person.age < 65 and not defender.on_birth_leave(person) and not defender.is_pregnant(person) and int(person.id) not in available:
                campaign.militia.append(int(person.id))
                if campaign.militia.size() >= mini(8, maxi(0, defender.workforce_capacity() - 3)): break
        campaign.defender_start = campaign.militia.size()
        defender.emergency_defenders.append_array(campaign.militia)
        defender.clamp_assignments()
    attacker.announce("Battle joined against " + session.civilizations[campaign.defender].name + ".")
    defender.announce("Under attack. Standing order: " + defender.defense_order + ".")
    revision += 1
    if campaign.defender_start == 0: finish(session, campaign, true, "No assigned defenders opposed the expedition.")

func groups_for(session, campaign: Dictionary) -> Array:
    var groups: Array = []
    var defender = session.civilizations[campaign.defender].sim
    for army_id in campaign.defender_armies:
        var army := find_army(defender, int(army_id))
        if not army.is_empty() and army.status == "Defending": groups.append(army)
    return groups

func strength(group: Dictionary, defending: bool, opponent: Dictionary) -> float:
    var count: int = group.soldiers.size()
    var spec: Dictionary = UNITS[group.unit]
    var commander: Dictionary = COMMANDERS.get(group.commander, COMMANDERS["None"])
    var tactic: String = group.tactic
    if group.autonomy and group.commander != "None":
        tactic = "Skirmish" if group.unit == "Archers" else "Hold ground" if defending or commander.style == "Steadfast" else "Flank" if commander.style == "Swift" else "Advance"
    var power := count * float(spec.defense if defending else spec.attack) * float(commander.defense if defending else commander.attack)
    power *= (0.45 + float(group.morale) / 100.0 * 0.55) * (1.0 + float(group.experience) * 0.2)
    if tactic == "Hold ground": power *= 1.20 if defending else 0.9
    if tactic == "Advance": power *= 0.95 if defending else 1.12
    if tactic == "Flank": power *= 1.2 if opponent.get("formation", "Line") != "Loose" else 0.9
    if tactic == "Skirmish": power *= 1.20 if group.unit == "Archers" else 0.85
    if group.formation == "Shield wall": power *= 1.25 if defending and group.unit == "Spearmen" else 0.9
    if group.formation == "Loose": power *= 1.15 if opponent.get("unit", "Militia") == "Archers" else 0.95
    if group.unit == "Archers" and opponent.get("formation", "Line") == "Shield wall": power *= 0.75
    return power

func losses(simulation, ids: Array, count: int) -> int:
    var removed := 0
    for id in ids.duplicate():
        if removed >= count or simulation.people.size() <= 1: break
        for person in simulation.people:
            if int(person.id) == int(id):
                simulation.people.erase(person)
                ids.erase(id)
                removed += 1
                break
    simulation.population = simulation.people.size()
    simulation.clamp_assignments()
    return removed

func resolve_round(session, campaign: Dictionary) -> void:
    var attacker = session.civilizations[campaign.attacker].sim
    var defender = session.civilizations[campaign.defender].sim
    var army := find_army(attacker, int(campaign.army))
    for group in defender.armies:
        if group.status == "Ready" and not group.get("reserve", false) and group.get("defend_home", true) and int(group.id) not in campaign.defender_armies:
            group.status = "Defending"
            campaign.defender_armies.append(int(group.id))
            campaign.defender_start += group.soldiers.size()
    var defenders := groups_for(session, campaign)
    var opponent: Dictionary = defenders[0] if not defenders.is_empty() else {"unit": "Militia", "formation": "Line"}
    var attack_power := strength(army, false, opponent)
    var defense_power: float = campaign.militia.size() * 0.6 * float(campaign.militia_morale) / 65.0
    for group in defenders: defense_power += strength(group, true, army)
    defense_power *= 1.0 + defender.fortification_bonus()
    if defender.defense_order == "Counterattack": defense_power *= 1.1
    if defender.resources.food <= 0: defense_power *= 0.65
    if army.supplies <= 0: attack_power *= 0.6
    var total := maxf(0.01, attack_power + defense_power)
    var attacking_before: int = army.soldiers.size()
    var defending_before: int = campaign.militia.size()
    for group in defenders: defending_before += group.soldiers.size()
    if attacking_before == 0:
        finish(session, campaign, false, "The attacking force was lost.")
        return
    var attack_losses := maxi(1, roundi(defense_power / total * attacking_before * 0.28)) if defense_power > 0 else 0
    var defend_losses := maxi(1, roundi(attack_power / total * defending_before * 0.28)) if defending_before > 0 else 0
    campaign.attacker_losses += losses(attacker, army.soldiers, attack_losses)
    var remaining_losses := defend_losses
    for group in defenders:
        var killed := losses(defender, group.soldiers, mini(remaining_losses, group.soldiers.size()))
        campaign.defender_losses += killed
        remaining_losses -= killed
        group.morale = maxf(0, float(group.morale) - 5.0 - killed / maxf(1, defending_before) * 65)
        if group.morale <= maxf(float(group.retreat), 55.0 if defender.defense_order == "Preserve people" else 15.0): group.status = "Recovering"
    if remaining_losses > 0:
        var fallen := losses(defender, campaign.militia, remaining_losses)
        campaign.defender_losses += fallen
        campaign.militia_losses = int(campaign.get("militia_losses", 0)) + fallen
    campaign.militia_morale = maxf(0, float(campaign.militia_morale) - 10.0 - defend_losses / maxf(1, defending_before) * 60)
    army.morale = maxf(0, float(army.morale) - 5.0 - attack_losses / maxf(1, attacking_before) * 65)
    campaign.rounds += 1
    var surviving_defenders: int = campaign.militia.size()
    var defender_morale: float = campaign.militia_morale if not campaign.militia.is_empty() else 0.0
    for group in defenders:
        if group.status != "Defending": continue
        surviving_defenders += group.soldiers.size()
        if not group.soldiers.is_empty(): defender_morale = maxf(defender_morale, float(group.morale))
    attacker.tick(0)
    defender.tick(0)
    if army.soldiers.is_empty() or army.morale <= army.retreat:
        finish(session, campaign, false, "Attackers withdrew at their retreat threshold.")
    elif surviving_defenders == 0 or defender_morale <= (55 if defender.defense_order == "Preserve people" else 30):
        finish(session, campaign, true, "Defenders withdrew; the attacking army won the battle.")
    elif campaign.rounds >= 8:
        finish(session, campaign, false, "The defenders held through eight days of fighting.")
    revision += 1

func release_defenders(session, campaign: Dictionary) -> void:
    var defender = session.civilizations[campaign.defender].sim
    for group in groups_for(session, campaign):
        if group.status == "Defending": group.status = "Recovering" if group.morale < 60 else "Ready"
    for id in campaign.militia: defender.emergency_defenders.erase(id)
    # Remove fallen militia IDs as well; only active battle reservations survive.
    var still_reserved: Array = []
    for other in campaigns:
        if other.id != campaign.id and other.defender == campaign.defender and other.phase == "Fighting": still_reserved.append_array(other.militia)
    defender.emergency_defenders = still_reserved
    defender.clamp_assignments()

func finish(session, campaign: Dictionary, won: bool, reason: String) -> void:
    var attacker = session.civilizations[campaign.attacker].sim
    var defender = session.civilizations[campaign.defender].sim
    var army := find_army(attacker, int(campaign.army))
    if campaign.phase in ["Returning", "Raiding"]: return
    if not won and campaign.rounds > 0:
        for group in groups_for(session, campaign): group.experience = minf(1.0, float(group.experience) + 0.10)
    release_defenders(session, campaign)
    var loot := {"food": 0.0, "wood": 0.0, "stone": 0.0}
    var return_point := campaign_point(campaign)
    if won and not army.is_empty():
        var capacity: float = army.soldiers.size() * 2.0 if campaign.get("mission", "Raid") == "Raid" else 0.0
        for resource in loot:
            var amount := minf(capacity, defender.resources[resource] * (0.05 if defender.defense_order == "Preserve people" else 0.15))
            loot[resource] = amount
            defender.resources[resource] -= amount
            capacity -= amount
        army.cargo = loot
        if campaign.rounds > 0: army.experience = minf(1.0, float(army.experience) + 0.15)
    if not army.is_empty():
        # Careful commanders soften morale damage from an ordered withdrawal.
        if not won: army.morale = maxf(0, float(army.morale) - (3 if army.commander == "Tovan" else 8))
        army.status = "Returning"
    var report := {"day": session.world_day, "attacker": session.civilizations[campaign.attacker].name, "defender": session.civilizations[campaign.defender].name, "outcome": ("%s succeeded" % campaign.get("mission", "Raid")) if won else "Attack repelled / withdrawn", "reason": reason, "rounds": campaign.rounds, "attacker_losses": campaign.attacker_losses, "defender_losses": campaign.defender_losses, "loot": loot}
    for simulation in [attacker, defender]:
        simulation.battle_reports.push_front(report.duplicate(true))
        if simulation.battle_reports.size() > 20: simulation.battle_reports.resize(20)
        simulation.announce("%s: %s (%d attacking / %d defending casualties)." % [report.outcome, reason, campaign.attacker_losses, campaign.defender_losses])
    campaign.return_start = clampf(float(campaign.elapsed) / float(campaign.travel), 0, 1) if campaign.phase == "Marching" else 1.0
    campaign.return_days = maxf(0.05, float(campaign.elapsed)) if campaign.phase == "Marching" else campaign.travel
    campaign.return_point = [return_point.x, return_point.y]
    campaign.return_days = maxf(0.05, return_point.distance_to(SITES[int(campaign.from_slot)]) / march_speed(army)) if not army.is_empty() else 0.05
    campaign.phase = "Returning"
    campaign.elapsed = 0.0
    campaign.result = report.outcome
    campaign.loot = loot
    if won and float(loot.food) + float(loot.wood) + float(loot.stone) > 0:
        campaign.phase = "Raiding"
        army.status = "Raiding"
    revision += 1

func campaign_point(campaign: Dictionary) -> Vector2:
    var start: Vector2 = SITES[int(campaign.from_slot)]
    var end: Vector2 = SITES[int(campaign.to_slot)]
    if campaign.phase in ["Fighting", "Raiding"]: return end + Vector2(-3, 0)
    if campaign.phase == "Holding": return Vector2(campaign.hold_point[0], campaign.hold_point[1])
    if campaign.phase == "Returning" and campaign.has("return_point"):
        return Vector2(campaign.return_point[0], campaign.return_point[1]).lerp(start, clampf(float(campaign.elapsed) / maxf(0.01, float(campaign.return_days)), 0, 1))
    if campaign.phase == "Returning":
        return start.lerp(end, float(campaign.get("return_start", 1.0))).lerp(start, clampf(float(campaign.elapsed) / maxf(0.01, float(campaign.get("return_days", campaign.travel))), 0, 1))
    if campaign.has("route_start"): start = Vector2(campaign.route_start[0], campaign.route_start[1])
    return start.lerp(end, clampf(float(campaign.elapsed) / maxf(0.01, float(campaign.travel)), 0, 1))

func campaign_view(session, campaign: Dictionary, token: String) -> Dictionary:
    var army := find_army(session.civilizations[campaign.attacker].sim, int(campaign.army))
    if campaign.attacker != token:
        var simulation = session.civilizations[token].sim
        var origin := Vector2(simulation.world_origin[0], simulation.world_origin[1])
        var point := campaign_point(campaign) - origin
        var observed := public_enemy_report(simulation.known_armies.get(str(int(campaign.id)), {}))
        var previous_point: Array = observed.get("point", [point.x, point.y])
        var movement := point - Vector2(previous_point[0], previous_point[1])
        observed.merge({"id": campaign.id, "own": false, "attacker": session.civilizations[campaign.attacker].name, "point": [point.x, point.y], "last_seen": session.world_day, "phase": str(campaign.phase) if campaign.phase in ["Fighting", "Raiding"] else "Moving"}, true)
        if movement.length() > 0.001: observed.heading = atan2(movement.x, movement.y)
        var party_sight := false
        for mission in simulation.scout_missions:
            if point.distance_to(simulation.mission_position(mission)) <= 7: party_sight = true
        if simulation.scout_missions.is_empty() and not simulation.scout_mission.is_empty() and point.distance_to(simulation.scout_position()) <= 7: party_sight = true
        if party_sight:
            observed.merge({"intel_scouted": true, "last_scouted": session.world_day, "unit": army.get("unit", "Militia"), "count": army.get("soldiers", []).size(), "formation": army.get("formation", "Line"), "commander": army.get("commander", "")}, true)
        observed["scene"] = battle_scene(session, campaign, token)
        return observed
    var view: Dictionary = {"id": campaign.id, "army": campaign.army, "own": campaign.attacker == token, "attacker": session.civilizations[campaign.attacker].name, "defender": session.civilizations[campaign.defender].name, "from_slot": campaign.from_slot, "to_slot": campaign.to_slot, "phase": campaign.phase, "elapsed": campaign.elapsed, "travel": campaign.travel, "return_start": campaign.get("return_start", 1.0), "return_days": campaign.get("return_days", campaign.travel), "rounds": campaign.rounds, "count": army.get("soldiers", []).size(), "unit": army.get("unit", "Militia"), "formation": army.get("formation", "Line"), "commander": army.get("commander", ""), "morale": army.get("morale", 0), "result": campaign.result, "name": army_name(army) if not army.is_empty() else "Army", "mission": campaign.get("mission", "Raid"), "messengers": campaign.get("messengers", []), "route_start": campaign.get("route_start", [SITES[int(campaign.from_slot)].x, SITES[int(campaign.from_slot)].y]), "return_point": campaign.get("return_point", [SITES[int(campaign.from_slot)].lerp(SITES[int(campaign.to_slot)], float(campaign.get("return_start", 1.0))).x, SITES[int(campaign.from_slot)].lerp(SITES[int(campaign.to_slot)], float(campaign.get("return_start", 1.0))).y]), "hold_point": campaign.get("hold_point", [0, 0])}

    view["cargo"] = army.get("cargo", {})
    view["scene"] = battle_scene(session, campaign, token)
    return view

func battle_scene(session, campaign: Dictionary, token: String) -> Dictionary:
    # Sent only with a currently visible campaign; never retained as enemy intelligence.
    var defender = session.civilizations[campaign.defender].sim
    var origin := Vector2(session.civilizations[token].sim.world_origin[0], session.civilizations[token].sim.world_origin[1])
    if not session.civilizations[token].sim.has_live_sight(campaign_point(campaign) - origin): return {}
    var fighters: Array = []
    for group in groups_for(session, campaign):
        for id in group.soldiers:
            if fighters.size() < 16: fighters.append({"unit": group.unit, "villager": false})
    for id in campaign.militia:
        if fighters.size() < 16: fighters.append({"unit": "Militia", "villager": true})
    var storage := Vector2(-6, 0) if defender.camp_object_present("cache") else Vector2(-4, 0)
    for building in defender.buildings:
        if building.kind == "Storehouse" and building.progress >= 1:
            storage = Vector2(3.0 * building.q, sqrt(3.0) * 2 * (building.r + building.q * 0.5))
            break
    var store_point := Vector2(defender.world_origin[0], defender.world_origin[1]) + storage - origin
    return {"defenders": fighters, "attacker_losses": campaign.attacker_losses, "defender_losses": campaign.defender_losses, "militia_losses": campaign.get("militia_losses", 0), "storage": [store_point.x, store_point.y], "loot": campaign.get("loot", {}), "at_home": campaign.defender == token}

static func public_enemy_report(report: Dictionary) -> Dictionary:
    # A whitelist also strips private fields from historical saved observations.
    var safe: Dictionary = {"own": false, "unit": "Unknown", "count": 3, "formation": "Loose", "commander": "Unknown", "intel_scouted": false, "heading": 0.0}
    for key in ["id", "attacker", "point", "last_seen", "phase", "heading"]:
        if report.has(key): safe[key] = report[key]
    if report.get("intel_scouted", false) and report.has("last_scouted"):
        for key in ["intel_scouted", "last_scouted", "unit", "count", "formation", "commander"]:
            if report.has(key): safe[key] = report[key]
    return safe

func public_campaigns(session, token: String) -> Array:
    var result: Array = []
    var simulation = session.civilizations[token].sim
    var origin := Vector2(simulation.world_origin[0], simulation.world_origin[1])
    for campaign in campaigns:
        var local_point := campaign_point(campaign) - origin
        if campaign.attacker != token and not simulation.has_live_sight(local_point): continue
        result.append(campaign_view(session, campaign, token))
    return result
