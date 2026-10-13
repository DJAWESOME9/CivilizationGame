extends RefCounted

const UNITS = {
    "Militia": {"attack": 1.0, "defense": 0.8, "wood": 1.0, "stone": 0.0, "days": 10.0, "tech": "Toolmaking"},
    "Spearmen": {"attack": 1.5, "defense": 1.8, "wood": 2.0, "stone": 1.0, "days": 20.0, "tech": "Stoneworking"},
    "Archers": {"attack": 1.8, "defense": 0.9, "wood": 3.0, "stone": 1.0, "days": 30.0, "tech": "Hunting"}
}
const COMMANDERS = {
    "Aren": {"style": "Steadfast", "attack": 1.0, "defense": 1.20, "description": "Shield discipline: +20% defense."},
    "Mira": {"style": "Swift", "attack": 1.15, "defense": 1.0, "description": "Rapid maneuver: +15% attack; marches 20% faster."},
    "Tovan": {"style": "Careful", "attack": 1.05, "defense": 1.10, "description": "Measured leadership: +5% attack, +10% defense; less morale lost on withdrawal."}
}
const TACTICS = ["Advance", "Hold ground", "Flank", "Skirmish"]
const FORMATIONS = ["Line", "Shield wall", "Loose"]
const DEFENSES = ["Hold settlement", "Counterattack", "Preserve people"]
# Keep the original slots stable for saved worlds. All eight sites remain on
# the western bank and within scouting range from every starting region.
const SITES = [Vector2(-32, -28), Vector2(-32, 28), Vector2(-88, -28), Vector2(-88, 28), Vector2(-32, 0), Vector2(-88, 0), Vector2(-60, -44), Vector2(-60, 44)]
var campaigns: Array = []
var next_campaign := 1
var revision := 0

static func find_army(simulation, army_id: int) -> Dictionary:
    for army in simulation.armies:
        if int(army.id) == army_id: return army
    return {}

static func recruit_block(simulation, unit: String, count: int, commander: String) -> String:
    if not UNITS.has(unit) or not COMMANDERS.has(commander): return "Choose a unit type and commander."
    if count < 1 or count > 30: return "Recruit between 1 and 30 soldiers per group."
    var spec: Dictionary = UNITS[unit]
    if spec.tech not in simulation.technologies: return "Requires " + spec.tech + "."
    if simulation.completed("Training Grounds") == 0: return "Build training grounds before training soldiers."
    var housing_used := 0
    for army in simulation.armies: housing_used += army.soldiers.size()
    if housing_used + count > simulation.military_capacity(): return "Not enough military housing. Each completed barracks supports 12 soldiers."
    for army in simulation.armies:
        if army.commander == commander: return "This commander already leads a group."
    var available := 0
    for person in simulation.people:
        if person.age >= 16 and person.age < 65 and person.training.is_empty() and int(person.id) not in simulation.military_ids() and int(person.id) not in simulation.scouting_units(): available += 1
    if count > available - 3: return "Keep at least three available civilians; there are not enough recruits."
    if simulation.resources.wood < spec.wood * count or simulation.resources.stone < spec.stone * count: return "Not enough wood or stone for their equipment."
    return ""

static func recruit(simulation, unit: String, count: int, commander: String) -> String:
    var blocked := recruit_block(simulation, unit, count, commander)
    if not blocked.is_empty(): return blocked
    var soldiers: Array = []
    var reserved: Array = simulation.military_ids()
    for person in simulation.people:
        if person.age >= 16 and person.age < 65 and person.training.is_empty() and int(person.id) not in reserved and int(person.id) not in simulation.scouting_units():
            soldiers.append(int(person.id))
            if soldiers.size() == count: break
    var spec: Dictionary = UNITS[unit]
    simulation.resources.wood -= spec.wood * count
    simulation.resources.stone -= spec.stone * count
    simulation.armies.append({"id": simulation.next_army_id, "unit": unit, "soldiers": soldiers, "commander": commander, "status": "Training", "training": 0.0, "morale": 100.0, "experience": 0.0, "tactic": "Hold ground", "formation": "Line", "autonomy": true, "retreat": 35, "supplies": 0.0, "cargo": {"food": 0.0, "wood": 0.0, "stone": 0.0}})
    simulation.next_army_id += 1
    simulation.clamp_assignments()
    simulation.prepare_roster(simulation.effective_assignments())
    simulation.announce("%d %s began training under %s; they have left civilian duties." % [count, unit.to_lower(), commander])
    return "Training commissioned; equipment paid up front."

static func army_order(simulation, action: String, args: Array) -> String:
    if action == "recruit":
        if args.size() != 3 or not args[0] is String or not args[1] is int or not args[2] is String: return "Invalid recruitment order."
        return recruit(simulation, args[0], args[1], args[2])
    if action == "defense":
        if args.size() != 1 or args[0] not in DEFENSES: return "Invalid defense order."
        simulation.defense_order = args[0]
        simulation.announce("Standing defense order: " + args[0] + ".")
        return "Standing defense order saved; it also applies while you are offline."
    if args.is_empty() or not args[0] is int: return "Choose an army."
    var army := find_army(simulation, args[0])
    if army.is_empty(): return "That army no longer exists."
    if action == "appoint":
        if args.size() != 2 or args[1] not in COMMANDERS: return "Choose a commander."
        if army.status not in ["Ready", "Training", "Recovering"]: return "Reassign commanders while the army is home."
        for other in simulation.armies:
            if other.id != army.id and other.commander == args[1]: return "That commander already leads another group."
        army.commander = args[1]
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
        army.autonomy = args[3]
        army.retreat = clampi(args[4], 15, 70)
        return "Commander orders updated."
    return "Unknown military order."

func launch(session, token: String, army_id: int, target_slot: int) -> String:
    var attacker = session.civilizations[token].sim
    var army := find_army(attacker, army_id)
    if army.is_empty() or army.status != "Ready": return "Choose a trained army at home."
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
    var defender = session.civilizations[target].sim
    campaigns.append({"id": next_campaign, "attacker": token, "defender": target, "army": army_id, "phase": "Marching", "elapsed": 0.0, "travel": travel, "round_clock": 0.0, "rounds": 0, "attacker_losses": 0, "defender_losses": 0, "defender_armies": [], "attacker_start": army.soldiers.size(), "defender_start": 0, "militia": [], "militia_morale": 65.0, "result": "", "loot": {"food": 0.0, "wood": 0.0, "stone": 0.0}, "from_slot": session.civilizations[token].slot, "to_slot": target_slot})
    next_campaign += 1
    attacker.announce("%s leads %d %s on a raid against %s." % [army.commander, army.soldiers.size(), army.unit.to_lower(), session.civilizations[target].name])
    # Defenders discover approaching armies through actual sight, not launch notifications.
    revision += 1
    return "Army dispatched; provisions reserved. Your target can be offline."

func recall(session, token: String, army_id: int) -> String:
    for campaign in campaigns:
        if campaign.attacker == token and int(campaign.army) == army_id and campaign.phase in ["Marching", "Fighting"]:
            finish(session, campaign, false, "Commander ordered withdrawal.")
            return "Army withdrawing. Survivors return over time."
    return "That army is not on an active expedition."

func advance(session, days: float) -> void:
    for campaign in campaigns.duplicate():
        var sim = session.civilizations[campaign.attacker].sim
        var army := find_army(sim, int(campaign.army))
        if army.is_empty():
            finish(session, campaign, false, "The expedition has no active soldiers remaining.")
            release_defenders(session, campaign)
            campaigns.erase(campaign)
            revision += 1
            continue
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
        if group.status == "Ready":
            group.status = "Defending"
            campaign.defender_armies.append(int(group.id))
            campaign.defender_start += group.soldiers.size()
    # Emergency militia use actual available adults, including those working civilian jobs.
    if campaign.defender_armies.is_empty() and defender.defense_order != "Preserve people" and defender.workforce_capacity() > 3:
        var available: Array = defender.military_ids() + defender.scouting_units()
        for person in defender.people:
            if person.age >= 16 and person.age < 65 and int(person.id) not in available:
                campaign.militia.append(int(person.id))
                if campaign.militia.size() >= mini(8, maxi(0, defender.workforce_capacity() - 3)): break
        campaign.defender_start = campaign.militia.size()
        defender.emergency_defenders.append_array(campaign.militia)
        defender.clamp_assignments()
    attacker.announce("Battle joined against " + session.civilizations[campaign.defender].name + ".")
    defender.announce("Under attack. Standing order: " + defender.defense_order + ".")
    revision += 1
    if campaign.defender_start == 0: finish(session, campaign, true, "The defenders preserved their civilians and yielded the stores.")

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
    var commander: Dictionary = COMMANDERS[group.commander]
    var tactic: String = group.tactic
    if group.autonomy:
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
        if group.status == "Ready" and int(group.id) not in campaign.defender_armies:
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
    if remaining_losses > 0: campaign.defender_losses += losses(defender, campaign.militia, remaining_losses)
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
        finish(session, campaign, true, "Defenders withdrew; the raid reached the stores.")
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
    if campaign.phase == "Returning": return
    if not won and campaign.rounds > 0:
        for group in groups_for(session, campaign): group.experience = minf(1.0, float(group.experience) + 0.10)
    release_defenders(session, campaign)
    var loot := {"food": 0.0, "wood": 0.0, "stone": 0.0}
    if won and not army.is_empty():
        var capacity: float = army.soldiers.size() * 2.0
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
    var report := {"day": session.world_day, "attacker": session.civilizations[campaign.attacker].name, "defender": session.civilizations[campaign.defender].name, "outcome": "Raid succeeded" if won else "Raid repelled / withdrawn", "reason": reason, "rounds": campaign.rounds, "attacker_losses": campaign.attacker_losses, "defender_losses": campaign.defender_losses, "loot": loot}
    for simulation in [attacker, defender]:
        simulation.battle_reports.push_front(report.duplicate(true))
        if simulation.battle_reports.size() > 20: simulation.battle_reports.resize(20)
        simulation.announce("%s: %s (%d attacking / %d defending casualties)." % [report.outcome, reason, campaign.attacker_losses, campaign.defender_losses])
    campaign.return_start = clampf(float(campaign.elapsed) / float(campaign.travel), 0, 1) if campaign.phase == "Marching" else 1.0
    campaign.return_days = maxf(0.05, float(campaign.elapsed)) if campaign.phase == "Marching" else campaign.travel
    campaign.phase = "Returning"
    campaign.elapsed = 0.0
    campaign.result = report.outcome
    campaign.loot = loot
    revision += 1

func campaign_point(campaign: Dictionary) -> Vector2:
    var start: Vector2 = SITES[int(campaign.from_slot)]
    var end: Vector2 = SITES[int(campaign.to_slot)]
    if campaign.phase == "Fighting": return end + Vector2(-3, 0)
    if campaign.phase == "Returning":
        return start.lerp(end, float(campaign.get("return_start", 1.0))).lerp(start, clampf(float(campaign.elapsed) / maxf(0.01, float(campaign.get("return_days", campaign.travel))), 0, 1))
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
        observed.merge({"id": campaign.id, "own": false, "attacker": session.civilizations[campaign.attacker].name, "point": [point.x, point.y], "last_seen": session.world_day, "phase": "Fighting" if campaign.phase == "Fighting" else "Moving"}, true)
        if movement.length() > 0.001: observed.heading = atan2(movement.x, movement.y)
        var party_sight := false
        for mission in simulation.scout_missions:
            if point.distance_to(simulation.mission_position(mission)) <= 7: party_sight = true
        if simulation.scout_missions.is_empty() and not simulation.scout_mission.is_empty() and point.distance_to(simulation.scout_position()) <= 7: party_sight = true
        if party_sight:
            observed.merge({"intel_scouted": true, "last_scouted": session.world_day, "unit": army.get("unit", "Militia"), "count": army.get("soldiers", []).size(), "formation": army.get("formation", "Line"), "commander": army.get("commander", "")}, true)
        return observed
    return {"id": campaign.id, "army": campaign.army, "own": campaign.attacker == token, "attacker": session.civilizations[campaign.attacker].name, "defender": session.civilizations[campaign.defender].name, "from_slot": campaign.from_slot, "to_slot": campaign.to_slot, "phase": campaign.phase, "elapsed": campaign.elapsed, "travel": campaign.travel, "return_start": campaign.get("return_start", 1.0), "return_days": campaign.get("return_days", campaign.travel), "rounds": campaign.rounds, "count": army.get("soldiers", []).size(), "unit": army.get("unit", "Militia"), "formation": army.get("formation", "Line"), "commander": army.get("commander", ""), "morale": army.get("morale", 0), "result": campaign.result}

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
