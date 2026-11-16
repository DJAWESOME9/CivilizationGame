extends RefCounted

# Remote reserves are separate from the settlement's near-to-far deposits.
const HOME := Vector2(-4, 0)
const SITES = [
    {"name": "Northern stone ridge", "point": Vector2(-29, -22), "resource": "stone", "job": "Quarrying", "reserve": 600.0},
    {"name": "Western woodland", "point": Vector2(-27, 19), "resource": "wood", "job": "Logging", "reserve": 800.0},
    {"name": "River meadow", "point": Vector2(1, 26), "resource": "food", "job": "Farming", "reserve": -1.0}
]

static func normalize(sim) -> void:
    # JSON restores array numbers as floats; resident membership requires integer IDs.
    for post in sim.outposts:
        post.units = post.units.map(func(id): return int(id))
        # Superseded crews return without deleting their people or cargo.
        if not post.get("manual_system_retired", false):
            post["manual_system_retired"] = true
            if post.stage == "Founding party":
                post.travel = 1.0 - clampf(float(post.travel), 0, 1)
                post.stage = "Returning"
            elif post.stage not in ["Recalling", "Returning"]:
                post.stage = "Recalling"
            post.enabled = false

static func find(sim, site: int) -> Dictionary:
    for post in sim.outposts:
        if int(post.site) == site: return post
    return {}

static func units(sim) -> Array:
    var result: Array = []
    for post in sim.outposts:
        result.append_array(post.units)
    return result

static func available(sim) -> Array:
    var result: Array = []
    var reserved: Array = sim.scouting_units() + sim.military_ids() + units(sim)
    for person in sim.people:
        if person.age >= 16 and person.age < 65 and not sim.on_birth_leave(person) and not sim.is_pregnant(person) and person.training.is_empty() and int(person.id) not in reserved:
            result.append(int(person.id))
    return result

static func route_block(sim, site: int) -> String:
    if site < 0 or site >= SITES.size(): return "Unknown resource site."
    var destination: Vector2 = SITES[site].point
    if not sim.explored.has(sim.cell_key(destination)): return "Scout this site first."
    # Land routes require a surveyed corridor and cannot cross water.
    var steps := ceili(HOME.distance_to(destination))
    for i in range(steps + 1):
        var point := HOME.lerp(destination, float(i) / steps)
        if sim.point_on_river(point): return "This land route crosses the river; bridges are not available yet."
        if not sim.explored.has(sim.cell_key(point)): return "Scout the entire route between town and this site first."
    return ""

static func founding_block(sim, site: int) -> String:
    var blocked := route_block(sim, site)
    if not blocked.is_empty(): return blocked
    if not find(sim, site).is_empty(): return "An outpost already occupies this site."
    if "Shelter Building" not in sim.technologies or "Storage" not in sim.technologies: return "Learn Shelter Building and Storage first."
    if not sim.job_unlocked(SITES[site].job): return "Unlock %s first." % SITES[site].job
    if available(sim).size() < 4: return "Four available adults are needed: three settlers and one carrier."
    if sim.resources.wood < 20 or sim.resources.stone < 5 or sim.resources.food < 16: return "Founding needs 20 wood, 5 stone and 16 food."
    return ""

static func road_cost(site: int) -> Dictionary:
    var length := HOME.distance_to(SITES[site].point)
    return {"wood": ceili(length * 0.5), "stone": ceili(length * 0.25), "work": length * 1.5}

static func order(sim, action: String, args: Array) -> String:
    if args.size() != 1 or not args[0] is int or args[0] < 0 or args[0] >= SITES.size(): return "Choose a resource site."
    var site: int = args[0]
    if action == "found_outpost":
        return "Place an Outpost from Build → Resources instead."
    var post := find(sim, site)
    if post.is_empty(): return "Found an outpost here first."
    if post.stage in ["Recalling", "Returning"]: return "This outpost is being recalled."
    if action == "outpost_road":
        if post.road_ordered: return "The road is already ordered."
        var cost := road_cost(site)
        if sim.resources.wood < cost.wood or sim.resources.stone < cost.stone: return "Road needs %d wood and %d stone." % [cost.wood, cost.stone]
        sim.resources.wood -= cost.wood
        sim.resources.stone -= cost.stone
        post.road_ordered = true
        return "Materials reserved. Settlers build the road before resuming production."
    if action == "outpost_route":
        post.enabled = not post.enabled
        return "Supply route resumed." if post.enabled else "Supply route paused; any current trip will finish."
    if action == "recall_outpost":
        # Gather the carrier before leaving; resources already in transit stay accounted for.
        if post.stage == "Founding party":
            post.stage = "Returning"
            post.travel = 1.0 - clampf(float(post.travel), 0, 1)
        else:
            post.stage = "Recalling"
        post.enabled = false
        return "Crew will gather at the outpost, pack available cargo and return. The road and remaining resource reserve are retained for later reuse."
    return "Unknown outpost order."

static func eligible(sim, id: int) -> bool:
    for person in sim.people:
        if int(person.id) == id: return person.age >= 16 and person.age < 65 and not sim.on_birth_leave(person)
    return false

static func duration(sim, post: Dictionary) -> float:
    var speed := 12.0 if float(post.road) >= 1.0 else 8.0
    return HOME.distance_to(SITES[int(post.site)].point) / (speed * sim.travel_factor())

static func room(sim) -> float:
    return maxf(0, sim.capacity() - sim.resources.food - sim.resources.wood - sim.resources.stone)

static func deposit(sim, post: Dictionary) -> void:
    var resource: String = SITES[int(post.site)].resource
    var amount := minf(float(post.cargo), room(sim))
    sim.resources[resource] += amount
    post.cargo -= amount
    post.delivered += amount

static func remember(sim, post: Dictionary) -> void:
    sim.outpost_sites[str(int(post.site))] = {"reserve": post.reserve, "road": post.road, "road_ordered": post.road_ordered}

static func release(sim, post: Dictionary) -> void:
    remember(sim, post)
    deposit(sim, post)
    var food := minf(float(post.food) + float(post.shipment_food), room(sim))
    sim.resources.food += food
    for person in sim.people:
        if int(person.id) not in post.units: continue
        var job: String = post.previous_jobs.get(str(int(person.id)), "")
        if job in sim.JOBS and eligible(sim, int(person.id)):
            person["scout_return_job"] = job
            if not sim.automatic_workforce: sim.assignments[job] += 1
    sim.outposts.erase(post)
    sim.announce("The %s crew returned; cargo beyond town storage capacity was left behind." % SITES[int(post.site)].name)

static func advance(sim, dt: float) -> void:
    if dt <= 0: return
    for post in sim.outposts.duplicate():
        var site: Dictionary = SITES[int(post.site)]
        # Keep retired residents with the party until it returns; remove only deaths.
        var retained: Array = []
        var working_count := 0
        for id in post.units:
            for person in sim.people:
                if int(person.id) == int(id):
                    retained.append(id)
                    if eligible(sim, int(id)): working_count += 1
                    break
        post.units = retained
        if post.units.is_empty():
            remember(sim, post)
            sim.outposts.erase(post)
            sim.announce("%s was abandoned: no working-age crew remains." % site.name)
            continue
        if working_count < 4 and post.stage not in ["Recalling", "Returning"]:
            if post.stage == "Founding party":
                post.stage = "Returning"
                post.travel = 1.0 - clampf(float(post.travel), 0, 1)
            else:
                post.stage = "Recalling"
            post.enabled = false
            sim.announce("%s is recalling its crew after losing a worker." % site.name)
        if post.stage not in ["Founding party", "Returning"]: sim.reveal_land(site.point, 7)
        # Everybody consumes from the local provision budget, including the carrier.
        var need: float = post.units.size() / 90.0 * sim.ration_level * dt
        post.food *= pow(1.0 - sim.food_spoilage_rate(), dt)
        if site.resource == "food": post.stock *= pow(1.0 - sim.food_spoilage_rate(), dt)
        var fed := minf(float(post.food), need)
        post.food -= fed
        var supplied := fed >= need - 0.00001
        post.hunger = maxf(0, float(post.hunger) - dt) if supplied else float(post.hunger) + dt
        if post.hunger >= 3 and post.stage not in ["Recalling", "Returning"]:
            if post.stage == "Founding party":
                post.stage = "Returning"
                post.travel = 1.0 - clampf(float(post.travel), 0, 1)
            else:
                post.stage = "Recalling"
            post.enabled = false
            sim.announce("%s ran out of provisions; its crew is returning." % site.name)
        if post.stage == "Returning":
            post.travel += dt / duration(sim, post)
            if post.travel >= 1: release(sim, post)
            continue
        # A carrier completes the current leg even when the route is paused/recalled.
        if post.leg in ["Outbound", "Inbound"]:
            post.route_progress += dt / duration(sim, post)
            if post.route_progress >= 1:
                post.route_progress = 0.0
                if post.leg == "Outbound":
                    post.food += post.shipment_food
                    post.shipment_food = 0.0
                    var capacity := 16.0 if post.road >= 1.0 else 8.0
                    post.cargo = minf(float(post.stock), capacity)
                    post.stock -= post.cargo
                    post.leg = "At camp" if post.stage == "Recalling" else "Inbound"
                else:
                    deposit(sim, post)
                    post.leg = "Home"
        if post.stage == "Recalling":
            # Carrier at home comes to collect the crew; one already outbound arrives normally.
            if post.leg == "Home":
                post.route_progress += dt / duration(sim, post)
                if post.route_progress < 1: continue
            elif post.leg != "At camp":
                continue
            post.cargo += minf(float(post.stock), maxf(0, 16.0 - float(post.cargo)))
            post.stock = 0.0
            post.stage = "Returning"
            post.travel = 0.0
            continue
        if post.stage == "Founding party":
            post.travel += dt / duration(sim, post)
            if post.travel >= 1:
                post.stage = "Building camp"
                post.leg = "At camp"
                sim.reveal_land(site.point, 7)
            continue
        if post.stage == "Building camp":
            if supplied: post.work += 3.0 * dt
            if post.work >= 18:
                post.stage = "Working"
                post.leg = "Inbound"
                post.route_progress = 0.0
            continue
        if post.road_ordered and post.road < 1.0:
            if supplied: post.road = minf(1.0, float(post.road) + 3.0 * dt / float(road_cost(int(post.site)).work))
        elif supplied:
            var season := int(sim.day / 90) % 4
            var rate := 0.10 if site.resource != "food" else 0.15
            var produced: float = 3.0 * dt * rate * ([1.1, 1.2, 0.85, 0.0][season] if site.resource == "food" else (0.75 if season == 3 else 1.0))
            produced = minf(produced, maxf(0, 48.0 - float(post.stock)))
            if site.resource != "food": produced = minf(produced, float(post.reserve))
            post.stock += produced
            if site.resource != "food": post.reserve -= produced
        if post.stage == "Working" and post.leg == "Home" and post.enabled:
            deposit(sim, post)
            # Retain overflow on the carrier instead of silently destroying a delivery.
            if post.cargo > 0.001: continue
            var food := minf(8.0, maxf(0, 16.0 - float(post.food)))
            if sim.resources.food < food: continue
            if food <= 0.01 and post.stock < 1: continue
            sim.resources.food -= food
            post.shipment_food = food
            post.leg = "Outbound"
            post.route_progress = 0.0

static func person_position(sim, id: int) -> Vector2:
    for post in sim.outposts:
        if id not in post.units: continue
        var point: Vector2 = SITES[int(post.site)].point
        if post.stage == "Founding party": return HOME.lerp(point, clampf(float(post.travel), 0, 1))
        if post.stage == "Returning": return point.lerp(HOME, clampf(float(post.travel), 0, 1))
        if post.stage == "Building camp" or post.leg == "At camp": return point
        if id == int(post.units.back()):
            var fraction := clampf(float(post.route_progress), 0, 1)
            if post.leg == "Outbound": return HOME.lerp(point, fraction)
            if post.leg == "Inbound": return point.lerp(HOME, fraction)
            if post.stage == "Recalling": return HOME.lerp(point, fraction)
            return point if post.leg == "At camp" else HOME
        return point + Vector2(sin(sim.day + id), cos(sim.day + id)) * 1.2
    return HOME
