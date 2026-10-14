extends RefCounted

# Host-authoritative resident combat. Positions, wounds, arrows and RNG persist
# inside campaigns. Map animation consumes these results and never deals damage.
const HEALTH := 100.0
const MELEE_RANGE := 1.15
const BOW_RANGE := 9.0
const STEP := 0.05

static func point(f: Dictionary) -> Vector2:
    return Vector2(f.point[0], f.point[1])

static func roll(b: Dictionary) -> float:
    b.rng = (int(b.rng) * 48271) % 2147483647
    return float(b.rng) / 2147483647.0

static func resident(sim, id: int) -> bool:
    for p in sim.people:
        if int(p.id) == id: return true
    return false

static func resident_age(sim, id: int) -> float:
    for person in sim.people:
        if int(person.id) == id: return float(person.age)
    return 16.0

static func group_for(w, session, c: Dictionary, f: Dictionary) -> Dictionary:
    return w.find_army(session.civilizations[c.attacker if int(f.side) == 0 else c.defender].sim, int(f.group))

static func add(w, b: Dictionary, group: Dictionary, id: int, side: int, pos: Vector2, civilian: bool = false, armed: bool = true) -> void:
    var unit: String = "Militia" if civilian else w.soldier_unit(group, id)
    var hp := float(group.get("health", {}).get(str(id), HEALTH))
    b.fighters.append({"id": id, "side": side, "group": int(group.get("id", -1)), "unit": unit, "civilian": civilian, "armed": armed, "point": [pos.x, pos.y], "hp": hp, "cooldown": 0.0, "state": "Fighting" if armed else "Fleeing", "action": "Idle", "target": [], "strike": 0, "heading": PI * 0.5 if side == 0 else -PI * 0.5})

static func start(w, session, c: Dictionary) -> void:
    var army: Dictionary = w.find_army(session.civilizations[c.attacker].sim, int(c.army))
    var home = session.civilizations[c.defender].sim
    var b := {"fighters": [], "arrows": [], "events": [], "serial": 0, "clock": 0.0, "rng": maxi(1, (int(c.id) * 193939 + int(session.world_day) * 17) % 2147483647), "starts": {}, "morale_clock": 0.0}
    c.battle = b
    c.civilian_ids = []
    var west := -22.0
    for building in home.buildings:
        west = minf(west, 3.0 * building.q - 7.0)
    b.west = west - 12.0
    b.east = 34.0
    for building in home.buildings: b.east = maxf(b.east, 3.0 * building.q + 12.0)
    # Place melee ahead and archers behind, preserving each resident's training.
    var sorted_ids: Array = army.soldiers.duplicate()
    sorted_ids.sort_custom(func(a, d): return int(w.soldier_unit(army, int(a)) == "Archers") < int(w.soldier_unit(army, int(d)) == "Archers"))
    var counts := {"front": 0, "back": 0}
    for id in sorted_ids:
        var back: bool = w.soldier_unit(army, int(id)) == "Archers"
        var lane := "back" if back else "front"
        var i: int = counts[lane]
        counts[lane] += 1
        var spacing := 1.0 if army.formation == "Loose" else 0.6 if army.formation == "Shield wall" else 0.8
        add(w, b, army, int(id), 0, Vector2(west - (4.0 if back else 0.0) - int(i / 6), (i % 6 - 2.5) * spacing))
    b.starts["0:" + str(int(army.id))] = army.soldiers.size()
    var used: Array = []
    var i := 0
    for group in w.groups_for(session, c):
        b.starts["1:" + str(int(group.id))] = group.soldiers.size()
        for id in group.soldiers:
            var pos := Vector2(-7.0 if w.soldier_unit(group, int(id)) == "Archers" else -11.0, (i % 8 - 3.5) * 0.8 + int(i / 8))
            # Archers take a protected position just behind an actual fortification.
            if w.soldier_unit(group, int(id)) == "Archers" and "Arrow Slits" in home.technologies:
                for building in home.buildings:
                    if building.progress >= 1 and building.kind in ["Wall", "Palisade"]:
                        pos = building_point(building) + Vector2(0, 1.4 + (i % 3) * 0.4)
                        break
            add(w, b, group, int(id), 1, pos)
            used.append(int(id))
            i += 1
    var unavailable: Array = home.military_ids() + home.scouting_units()
    # Fight back is the sole civilian rally policy. Attack leaves civilians alone.
    if home.civic_active("Fight back") and c.get("mission", "Raid") != "Attack":
        for person in home.people:
            var id := int(person.id)
            if person.age < 16 or person.age >= 65 or id in unavailable or home.on_birth_leave(person) or home.is_pregnant(person): continue
            if home.happiness < 55.0 + (roll(b) * 10.0 - 5.0) or roll(b) > home.happiness / 100.0: continue
            c.militia.append(id)
            home.emergency_defenders.append(id)
            add(w, b, {}, id, 1, Vector2(-10, (i % 10 - 4.5) * 0.8), true)
            used.append(id)
            i += 1
    # Raze can attack residents physically present; remote expeditions are absent.
    # Raid civilians flee, and can be attacked only while obstructing the stores.
    if c.get("mission", "Raid") != "Attack":
        var away: Array = home.scouting_units()
        for group in home.armies:
            if group.status not in ["Ready", "Training", "Recovering", "Defending", "Surrendered"]: away.append_array(group.soldiers)
        for person in home.people:
            var id := int(person.id)
            if id in used or id in away: continue
            c.civilian_ids.append(id)
            home.emergency_defenders.append(id)
            add(w, b, {}, id, 1, Vector2(-6 + (i % 6) * 0.8, (int(i / 6) % 6 - 2.5) * 1.1), true, false)
            i += 1
    # Push initial positions out of fortification footprints.
    for f in b.fighters:
        for wall in walls(home):
            if inside(point(f), wall): f.point = [point(f).x, float(wall.center.y) + float(wall.half.y) + 0.4]
    home.clamp_assignments()

static func building_point(building: Dictionary) -> Vector2:
    return Vector2(3.0 * building.q, sqrt(3.0) * 2.0 * (building.r + building.q * 0.5))

static func walls(home) -> Array:
    var result: Array = []
    for building in home.buildings:
        if building.progress < 1 or building.kind not in ["Wall", "Palisade"]: continue
        result.append({"building": building, "center": building_point(building), "half": Vector2(1.7, 0.65) if building.kind == "Wall" else Vector2(1.55, 1.55)})
    return result

static func inside(p: Vector2, wall: Dictionary) -> bool:
    var d: Vector2 = (p - wall.center).abs()
    return d.x <= wall.half.x and d.y <= wall.half.y

static func blocker(a: Vector2, d: Vector2, obstacles: Array) -> Dictionary:
    # Slab intersection catches walls even when a fast step crosses their footprint.
    var direction := d - a
    var best: Dictionary = {}
    var best_t := 2.0
    for wall in obstacles:
        var low: Vector2 = wall.center - wall.half
        var high: Vector2 = wall.center + wall.half
        var entry := 0.0
        var leave := 1.0
        var hit := true
        for axis in range(2):
            if absf(direction[axis]) < 0.00001:
                if a[axis] < low[axis] or a[axis] > high[axis]: hit = false
            else:
                var t1: float = (low[axis] - a[axis]) / direction[axis]
                var t2: float = (high[axis] - a[axis]) / direction[axis]
                entry = maxf(entry, minf(t1, t2))
                leave = minf(leave, maxf(t1, t2))
        if hit and entry <= leave and entry < best_t:
            best = wall
            best_t = entry
    return best

static func event(b: Dictionary, kind: String, f: Dictionary, destination: Vector2) -> void:
    b.serial += 1
    b.events.append({"serial": b.serial, "kind": kind, "side": f.side, "id": f.id, "unit": f.unit, "civilian": f.civilian, "from": f.point.duplicate(), "to": [destination.x, destination.y], "time": b.clock})
    if b.events.size() > 96: b.events.pop_front()

static func withdraw(c: Dictionary, side: int, group_id: int) -> void:
    if not c.has("battle"): return
    for f in c.battle.fighters:
        if int(f.side) == side and (group_id < 0 or int(f.group) == group_id) and f.hp > 0 and f.state == "Fighting": f.state = "Retreating"

static func surrender(w, session, c: Dictionary, side: int, group_id: int) -> void:
    var sim = session.civilizations[c.attacker if side == 0 else c.defender].sim
    var group: Dictionary = w.find_army(sim, group_id)
    if group.is_empty(): return
    var newly_surrendered := false
    for f in c.battle.fighters:
        if int(f.side) != side or int(f.group) != group_id or f.hp <= 0 or f.state in ["Escaped", "Surrendered"]: continue
        f.state = "Surrendered"
        newly_surrendered = true
    if not newly_surrendered: return
    w.surrender_resources(session, c, side, group)
    if side == 0:
        c.attacker_surrendered = true
        c.erase("after_withdrawal")
        c.withdraw_reason = "The expedition surrendered its carried resources; survivors are returning home."
    else:
        # The battlefield is at their own town: leave combat and recover at home.
        group.status = "Recovering"
        group.morale = minf(float(group.morale), 55.0)

static func alive(f: Dictionary) -> bool:
    return f.hp > 0 and f.state != "Escaped"

static func can_target(c: Dictionary, f: Dictionary, target: Dictionary) -> bool:
    if not alive(target) or int(target.side) == int(f.side): return false
    if target.state == "Surrendered": return false
    if not target.civilian: return true
    if int(f.side) != 0: return target.armed
    if c.get("mission", "Raid") == "Attack": return false
    if c.get("mission") == "Raze" or target.armed: return true
    return point(target).distance_to(storage(c)) <= 3.0 and point(f).distance_to(point(target)) <= 1.3

static func storage(c: Dictionary) -> Vector2:
    return Vector2(c.battle.get("storage", [-6.0, 0.0])[0], c.battle.get("storage", [-6.0, 0.0])[1])

static func damage_factor(w, group: Dictionary, f: Dictionary, target: Dictionary, defending: bool) -> float:
    var unit: String = f.unit
    var spec: Dictionary = w.UNITS[unit]
    if group.is_empty(): return 0.6 if not defending else 0.8
    var chief: Dictionary = w.COMMANDERS.get(group.commander, w.COMMANDERS["None"])
    var tactic: String = group.tactic
    if group.autonomy and group.commander != "None": tactic = "Skirmish" if unit == "Archers" else "Hold ground" if defending or chief.style == "Steadfast" else "Flank" if chief.style == "Swift" else "Advance"
    var value := float(spec.defense if defending else spec.attack) * float(chief.defense if defending else chief.attack)
    value *= (0.45 + float(group.morale) * 0.0055) * (1.0 + float(group.experience) * 0.2)
    if tactic == "Hold ground": value *= 1.2 if defending else 0.9
    if tactic == "Advance": value *= 0.95 if defending else 1.12
    if tactic == "Skirmish": value *= 1.2 if unit == "Archers" else 0.85
    if tactic == "Flank": value *= 0.9 if target.get("formation", "Line") == "Loose" else 1.2
    if group.formation == "Shield wall": value *= 1.25 if defending and unit == "Spearmen" else 0.9
    if group.formation == "Loose": value *= 1.15 if target.get("unit", "Militia") == "Archers" else 0.95
    if unit == "Archers" and target.get("formation", "Line") == "Shield wall": value *= 0.75
    return maxf(0.1, value)

static func hit(w, session, c: Dictionary, f: Dictionary, target: Dictionary, amount: float) -> void:
    if not alive(target): return
    target.hp = maxf(0, float(target.hp) - amount)
    var group := group_for(w, session, c, target)
    if not group.is_empty():
        if not group.has("health"): group.health = {}
        group.health[str(int(target.id))] = target.hp
    if target.hp > 0: return
    var sim = session.civilizations[c.attacker if int(target.side) == 0 else c.defender].sim
    # Use the actual soldier array, so the next simulation tick cannot resurrect a casualty.
    var ids: Array = group.soldiers if not group.is_empty() else [int(target.id)]
    var killed: int = w.losses(sim, ids, 1) if int(target.id) in ids and ids.size() == 1 else 0
    if not group.is_empty() and ids.size() > 1:
        # losses removes the first IDs supplied, so remove this particular resident only.
        var victim: Array = [int(target.id)]
        killed = w.losses(sim, victim, 1)
        group.soldiers.erase(int(target.id))
    if int(target.side) == 0: c.attacker_losses += killed
    else:
        c.defender_losses += killed
        if int(target.id) in c.militia:
            c.militia.erase(int(target.id))
            sim.emergency_defenders.erase(int(target.id))
            c.militia_losses = int(c.get("militia_losses", 0)) + killed
    if not group.is_empty():
        var initial := maxi(1, int(c.battle.starts.get(str(int(target.side)) + ":" + str(int(group.id)), 1)))
        group.morale = maxf(0, float(group.morale) - 65.0 / initial)
        w.trim_load(group)
    event(c.battle, "Fall", target, point(target))

static func move(f: Dictionary, destination: Vector2, speed: float, days: float, obstacles: Array, flank: bool = false) -> void:
    var p := point(f)
    var next := p.move_toward(destination, speed * days)
    var wall := blocker(p, next, obstacles)
    if not wall.is_empty():
        # Move along the wall to its nearest open end rather than walking through it.
        var center: Vector2 = wall.center
        var half: Vector2 = wall.half
        var corner := Vector2(center.x + (half.x + 0.5) * (1 if p.x >= center.x else -1), center.y + (half.y + 0.5) * (1 if p.y >= center.y else -1))
        next = p.move_toward(corner, speed * days)
        if not blocker(p, next, obstacles).is_empty():
            var around := p.move_toward(Vector2(corner.x, p.y), speed * days)
            if blocker(p, around, obstacles).is_empty() and around.distance_to(p) > 0.001: next = around
            else:
                around = p.move_toward(Vector2(p.x, corner.y), speed * days)
                next = around if blocker(p, around, obstacles).is_empty() else p
    if flank and p.distance_to(destination) > 4:
        var side_step := next + Vector2(0, (1 if int(f.id) % 2 == 0 else -1) * speed * days * 0.35)
        if blocker(p, side_step, obstacles).is_empty(): next = side_step
    var direction := next - p
    f.action = "Marching" if direction.length() > 0.001 else "Idle"
    if direction.length() > 0.001: f.heading = atan2(direction.x, direction.y)
    f.point = [next.x, next.y]

static func loot(w, home, army: Dictionary, days: float) -> void:
    w.trim_load(army)
    var room: float = maxf(0, w.carry_capacity(army) - w.carried(army))
    var load := minf(room, army.soldiers.size() * days * 2.0)
    # Fill from the most abundant store first; no percentage-of-stores limit.
    var resources: Array = ["food", "wood", "stone"]
    resources.sort_custom(func(a, d): return float(home.resources[a]) > float(home.resources[d]))
    for resource in resources:
        var amount := minf(load, float(home.resources[resource]))
        army.cargo[resource] = float(army.cargo.get(resource, 0)) + amount
        home.resources[resource] -= amount
        load -= amount

static func advance(w, session, c: Dictionary, days: float) -> void:
    if not c.has("battle"): start(w, session, c) # Legacy active battles migrate in place.
    var remaining := days
    while remaining > 0.000001 and c.phase == "Fighting":
        var step := minf(STEP, remaining)
        step_battle(w, session, c, step)
        remaining -= step
    w.revision += 1

static func step_battle(w, session, c: Dictionary, days: float) -> void:
    var b: Dictionary = c.battle
    b.clock += days
    c.rounds = floori(float(b.clock))
    var home = session.civilizations[c.defender].sim
    var army: Dictionary = w.find_army(session.civilizations[c.attacker].sim, int(c.army))
    if army.is_empty():
        w.finish(session, c, false, "The attacking force was lost.")
        return
    # Store coordinates follow the actual completed storehouse/cache.
    b.storage = [-6.0, 0.0] if home.camp_object_present("cache") else [-4.0, 0.0]
    for building in home.buildings:
        if building.kind == "Storehouse" and building.progress >= 1:
            var pos := building_point(building)
            b.storage = [pos.x, pos.y]
            break
    # Newly present residents (for example births during a long siege) remain subject to Raze.
    if c.get("mission") == "Raze":
        var represented: Array = []
        for f in b.fighters:
            if int(f.side) == 1: represented.append(int(f.id))
        var away: Array = home.scouting_units()
        for group in home.armies:
            if group.status not in ["Ready", "Training", "Recovering", "Defending", "Surrendered"]: away.append_array(group.soldiers)
        for person in home.people:
            if int(person.id) in represented or int(person.id) in away: continue
            c.civilian_ids.append(int(person.id))
            home.emergency_defenders.append(int(person.id))
            add(w, b, {}, int(person.id), 1, Vector2(-4, int(person.id) % 6 - 3), true, false)
    # Reinforcements that become ready while fighting enter at the settlement.
    for group in home.armies:
        if group.status != "Ready" or group.get("reserve", false) or not group.get("defend_home", true) or int(group.id) in c.defender_armies: continue
        group.status = "Defending"
        c.defender_armies.append(int(group.id))
        b.starts["1:" + str(int(group.id))] = group.soldiers.size()
        for id in group.soldiers:
            var existing: Dictionary = {}
            for fighter in b.fighters:
                if int(fighter.side) == 1 and int(fighter.id) == int(id) and alive(fighter):
                    existing = fighter
                    break
            if existing.is_empty(): add(w, b, group, int(id), 1, Vector2(0, int(id) % 8 - 4))
            else:
                existing.merge({"group": group.id, "unit": w.soldier_unit(group, int(id)), "civilian": false, "armed": true, "state": "Fighting"}, true)
                c.civilian_ids.erase(int(id))
                c.militia.erase(int(id))
                home.emergency_defenders.erase(int(id))
    var obstacles := walls(home)
    # Resolve arrows that were actually released; arrows still land if their shooter falls.
    for arrow in b.arrows.duplicate():
        arrow.remaining -= days
        if arrow.remaining > 0: continue
        for target in b.fighters:
            if int(target.side) == int(arrow.side) or int(target.id) != int(arrow.target) or not alive(target) or not can_target(c, arrow.source, target): continue
            var barrier := blocker(Vector2(arrow.from[0], arrow.from[1]), point(target), obstacles)
            if barrier.is_empty() or arrow.slits: hit(w, session, c, arrow.source, target, float(arrow.damage))
            break
        b.arrows.erase(arrow)
    # Evaluate army orders against the number that entered this battle.
    var groups: Array = [army] + w.groups_for(session, c)
    for group in groups:
        var side := 0 if int(group.id) == int(army.id) and group == army else 1
        var start_count := maxi(1, int(b.starts.get(str(side) + ":" + str(int(group.id)), group.soldiers.size())))
        var casualty_pct: float = 100.0 * (start_count - group.soldiers.size()) / start_count
        var limit := int(group.get("casualty_limit", 50))
        if limit > 0 and casualty_pct >= limit:
            if group.get("casualty_action", "Retreat") == "Surrender": surrender(w, session, c, side, int(group.id))
            else: withdraw(c, side, int(group.id))
        if c.get("attacker_surrendered", false):
            w.finish(session, c, false, c.withdraw_reason)
            return
        var threshold := maxf(float(group.retreat), 55.0 if side == 1 and home.defense_order == "Preserve people" else 0.0)
        if group.morale <= threshold: withdraw(c, side, int(group.id))
    var militia_alive: int = b.fighters.filter(func(f): return int(f.side) == 1 and f.civilian and f.armed and alive(f)).size()
    if not c.militia.is_empty() and militia_alive < ceili((militia_alive + int(c.get("militia_losses", 0))) * 0.5):
        for f in b.fighters:
            if int(f.side) == 1 and f.civilian and f.armed and f.state == "Fighting": f.state = "Retreating"
    b.morale_clock += days
    if b.morale_clock >= 1.0:
        b.morale_clock -= 1.0
        for group in groups: group.morale = maxf(0, float(group.morale) - 1.0)
    var ordered_retreat: bool = b.fighters.any(func(f): return int(f.side) == 0 and f.state in ["Retreating", "Surrendered", "Escaped"])
    for f in b.fighters:
        var sim = session.civilizations[c.attacker if int(f.side) == 0 else c.defender].sim
        if alive(f) and not resident(sim, int(f.id)):
            f.hp = 0
            continue
        if not alive(f) or f.state == "Surrendered": continue
        f.cooldown = maxf(0, float(f.cooldown) - days)
        f.action = "Idle"
        var group := group_for(w, session, c, f)
        if f.state in ["Retreating", "Fleeing"]:
            # Civilians escape Raid. Raze pursues everyone present until killed.
            var direction := -1.0 if int(f.side) == 0 else 1.0
            var destination := Vector2(float(b.west) if direction < 0 else float(b.east), point(f).y)
            var speed: float = (6.0 if f.armed else 3.0) * (w.load_factor(group) if not group.is_empty() else 1.0)
            if c.get("mission") == "Raze" and not f.armed and point(f).x >= float(b.east) - 1: speed = 0.0
            move(f, destination, speed, days, obstacles)
            if point(f).distance_to(destination) < 0.4 and not (c.get("mission") == "Raze" and int(f.side) == 1 and not f.armed):
                f.state = "Escaped"
                if not group.is_empty() and int(f.side) == 1:
                    var still_here: bool = b.fighters.any(func(other): return int(other.side) == 1 and int(other.group) == int(f.group) and alive(other) and other.state != "Surrendered")
                    if not still_here: group.status = "Recovering"
            continue
        var target: Dictionary = {}
        var nearest := INF
        for enemy in b.fighters:
            if not can_target(c, f, enemy): continue
            var distance := point(f).distance_to(point(enemy))
            # Protect the rear: archers prefer the closest armed threat.
            if not enemy.armed and c.get("mission") != "Raze": distance += 10
            if distance < nearest:
                nearest = distance
                target = enemy
        if int(f.side) == 0 and c.get("mission") == "Raid" and not target.is_empty() and nearest > (BOW_RANGE if f.unit == "Archers" else 4.0) and point(target).distance_to(storage(c)) > 4.0:
            target = {}
        var objective := storage(c)
        if not target.is_empty(): objective = point(target)
        elif int(f.side) == 1: continue
        elif c.get("mission") == "Attack" or ordered_retreat: continue
        var cargo_full: bool = w.carry_capacity(army) - w.carried(army) < 0.05 or home.resources.food + home.resources.wood + home.resources.stone < 0.05
        if int(f.side) == 0 and c.get("mission") == "Raze" and target.is_empty() and cargo_full and c.get("destroy_buildings", false) and not home.buildings.is_empty():
            objective = building_point(home.buildings[0])
        var barrier := blocker(point(f), objective, obstacles)
        var archer: bool = f.unit == "Archers"
        var slit: bool = int(f.side) == 1 and archer and "Arrow Slits" in home.technologies and not barrier.is_empty() and point(f).distance_to(barrier.center) <= 3.5
        var reach := BOW_RANGE if archer else MELEE_RANGE
        var distance := point(f).distance_to(objective)
        var target_group: Dictionary = {} if target.is_empty() else group_for(w, session, c, target)
        var opposing := {"unit": target.get("unit", "Militia"), "formation": target_group.get("formation", "Line")}
        var own := {"unit": f.unit, "formation": group.get("formation", "Line")}
        var attack := damage_factor(w, group, f, opposing, int(f.side) == 1)
        if int(f.side) == 0 and army.supplies <= 0: attack *= 0.6
        if int(f.side) == 1:
            if home.resources.food <= 0: attack *= 0.65
            if home.defense_order == "Counterattack": attack *= 1.1
        if not barrier.is_empty() and not slit:
            var edge := point(f).clamp(barrier.center - barrier.half, barrier.center + barrier.half)
            if point(f).distance_to(edge) <= MELEE_RANGE and f.cooldown <= 0:
                # Both timber and stone must be breached; arrows cannot demolish walls.
                if not archer and int(f.side) == 0:
                    damage_building(home, barrier.building, attack * 20.0)
                    f.cooldown = 0.25
                    f.action = "Fighting"
                    f.target = [edge.x, edge.y]
                    f.strike += 1
                else: move(f, objective, 5.0, days, obstacles)
            else: move(f, objective, 6.0, days, obstacles)
            continue
        if not target.is_empty() and distance <= reach:
            if archer and distance < 3.0:
                var backwards := point(f) + (point(f) - objective).normalized() * 4.0
                move(f, backwards, 4.0, days, obstacles)
            if f.cooldown > 0: continue
            var defense := damage_factor(w, target_group, target, own, int(target.side) == 1)
            var amount := 20.0 * attack / maxf(0.3, defense) * (0.95 + roll(b) * 0.1)
            f.cooldown = 0.4 if archer else 0.25
            f.action = "Fighting"
            f.heading = atan2(objective.x - point(f).x, objective.y - point(f).y)
            f.target = [objective.x, objective.y]
            f.strike += 1
            if archer:
                b.arrows.append({"source": f.duplicate(true), "side": f.side, "target": target.id, "from": f.point.duplicate(), "remaining": maxf(0.03, distance / 30.0), "damage": amount, "slits": slit})
                event(b, "Arrow", f, objective)
            else: hit(w, session, c, f, target, amount)
        elif target.is_empty() and int(f.side) == 0 and c.get("mission") == "Raze" and cargo_full and c.get("destroy_buildings", false) and not home.buildings.is_empty() and distance <= 2.0:
            if f.cooldown <= 0:
                damage_building(home, home.buildings[0], attack * 20.0)
                f.cooldown = 0.25
                f.action = "Fighting"
        elif distance > (1.5 if target.is_empty() else reach * 0.85):
            var tactic: String = group.get("tactic", "Advance")
            # Holding defenders keep their line until an enemy is close; archers keep their distance.
            if int(f.side) == 1 and tactic == "Hold ground" and distance > (BOW_RANGE if archer else 5.0): continue
            move(f, objective, 6.0 * (w.load_factor(group) if not group.is_empty() else 1.0), days, obstacles, tactic == "Flank")
    var attackers: Array = b.fighters.filter(func(f): return int(f.side) == 0 and alive(f) and f.state != "Surrendered")
    if attackers.is_empty():
        w.finish(session, c, false, c.get("withdraw_reason", "Attackers were defeated, surrendered or withdrew after pursuit."))
        return
    if ordered_retreat: return
    var defenders: Array = b.fighters.filter(func(f): return int(f.side) == 1 and alive(f) and f.armed and f.state != "Surrendered")
    if c.get("mission") == "Attack":
        if defenders.is_empty(): w.finish(session, c, true, "The defending armies were defeated, surrendered or escaped.")
        return
    var at_store: bool = attackers.any(func(f): return point(f).distance_to(storage(c)) <= 2.0)
    var store_blocked: bool = defenders.any(func(f): return point(f).distance_to(storage(c)) <= 4.0)
    if at_store and not store_blocked: loot(w, home, army, days)
    var room: float = maxf(0, w.carry_capacity(army) - w.carried(army))
    var stores: float = home.resources.food + home.resources.wood + home.resources.stone
    if c.get("mission") == "Raid":
        if at_store and (room < 0.05 or stores < 0.05):
            withdraw(c, 0, -1)
            c.withdraw_reason = "Raid completed; surviving troops escaped with the resources they could carry."
            c.raid_success = true
    elif c.get("mission") == "Raze":
        var residents: bool = b.fighters.any(func(f): return int(f.side) == 1 and alive(f) and f.state != "Surrendered")
        if not residents and (not c.get("destroy_buildings", false) or home.buildings.is_empty()) and at_store and (room < 0.05 or stores < 0.05):
            if c.get("destroy_buildings", false):
                for id in home.STARTING_OBJECTS: home.camp_dismantling[id] = 1.0
                home.revision += 1
            w.finish(session, c, true, "Reachable residents were killed; troops that escaped remain alive. Available cargo space filled.")

static func damage_building(home, building: Dictionary, amount: float) -> void:
    var base := 420.0 if building.kind == "Wall" else 180.0 if building.kind == "Palisade" else 120.0
    building.combat_health = maxf(0, float(building.get("combat_health", base)) - amount)
    if building.combat_health <= 0:
        home.buildings.erase(building)
        home.announce(building.kind + " destroyed in battle.")
        home.revision += 1

static func w_cargo(c: Dictionary, session) -> float:
    var total := 0.0
    for army in session.civilizations[c.attacker].sim.armies:
        if int(army.id) != int(c.army): continue
        for amount in army.get("cargo", {}).values(): total += float(amount)
    return total

static func public_scene(session, c: Dictionary, token: String) -> Dictionary:
    if c.phase != "Fighting" or not c.has("battle"): return {}
    var b: Dictionary = c.battle
    var viewer = session.civilizations[token].sim
    var origin := Vector2(viewer.world_origin[0], viewer.world_origin[1])
    var home = session.civilizations[c.defender].sim
    var offset := Vector2(home.world_origin[0], home.world_origin[1]) - origin
    var fighters: Array = []
    for f in b.fighters:
        var pos := point(f) + offset
        if not alive(f) or f.state == "Surrendered" or not viewer.has_live_sight(pos): continue
        var target: Array = f.target
        var target_pos := Vector2(target[0], target[1]) + offset if target.size() == 2 else pos
        # Visible equipment/movement only. Health and private retreat orders stay host-side.
        fighters.append({"id": f.id, "side": f.side, "unit": f.unit, "civilian": f.civilian, "armed": f.armed, "age": resident_age(home if int(f.side) == 1 else session.civilizations[c.attacker].sim, int(f.id)), "point": [pos.x, pos.y], "action": f.action, "state": f.state, "heading": f.heading, "target": [target_pos.x, target_pos.y], "strike": f.strike, "own": (c.attacker if int(f.side) == 0 else c.defender) == token, "army": f.group if (c.attacker if int(f.side) == 0 else c.defender) == token else -1, "laden": int(f.side) == 0 and float(w_cargo(c, session)) > 0})
    var events: Array = []
    for e in b.events:
        if b.clock - e.time > 1.0: continue
        var from := Vector2(e.from[0], e.from[1]) + offset
        var to := Vector2(e.to[0], e.to[1]) + offset
        if not viewer.has_live_sight(from) or not viewer.has_live_sight(to): continue
        var visible: Dictionary = e.duplicate(true)
        visible.from = [from.x, from.y]
        visible.to = [to.x, to.y]
        events.append(visible)
    return {"fighters": fighters, "events": events, "serial": b.serial}
