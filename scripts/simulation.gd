extends RefCounted

const Warfare = preload("res://scripts/warfare.gd")

# Saved mission travel/progress retain their original units. Only movement
# advances faster; the three-day survey still follows the seasonal world clock.
const SCOUT_TRAVEL_RATE := 3.0
const CAMP_RADIUS := 12.0
const ELDER_DEATH_AGE_MIN := 65.0
const ELDER_DEATH_AGE_MAX := 75.0

const JOBS = ["Gathering", "Fishing", "Logging", "Quarrying", "Construction", "Farming"]
const BUILDINGS = {
    "House": {"wood": 18.0, "stone": 4.0, "work": 12.0},
    "Storehouse": {"wood": 24.0, "stone": 8.0, "work": 35.0},
    "Field": {"wood": 6.0, "stone": 0.0, "work": 15.0},
    "Well": {"wood": 8.0, "stone": 20.0, "work": 30.0},
    "School": {"wood": 30.0, "stone": 12.0, "work": 45.0},
    "Training Grounds": {"wood": 16.0, "stone": 4.0, "work": 20.0},
    "Barracks": {"wood": 24.0, "stone": 10.0, "work": 36.0},
    "Palisade": {"wood": 30.0, "stone": 4.0, "work": 30.0},
    "Wall": {"wood": 8.0, "stone": 24.0, "work": 40.0}
}
const TECHNOLOGIES = {
    "Scouting": 0.0,
    "Basketry": 0.5, "Hunting": 1.0, "Storage": 0.75, "Education": 2.0,
    "Toolmaking": 0.5, "Shelter Building": 0.5, "Fishing": 0.75, "Woodcutting": 0.75,
    "Planting": 1.0, "Preservation": 1.5, "Forestry": 1.0, "Crop Rotation": 2.0,
    "Stoneworking": 1.0, "Carpentry": 1.5, "Masonry": 2.0, "Sanitation": 2.0, "Waterworks": 2.5
}
const JOB_TECH = {"Gathering": "", "Fishing": "Fishing", "Logging": "Woodcutting", "Quarrying": "Stoneworking", "Construction": "Shelter Building", "Farming": "Planting"}
const PREREQUISITES = {
    "Scouting": [],
    "Basketry": [], "Hunting": ["Toolmaking"], "Storage": ["Shelter Building"], "Education": ["Carpentry"],
    "Toolmaking": [], "Shelter Building": ["Toolmaking"], "Fishing": ["Toolmaking"], "Woodcutting": ["Toolmaking"],
    "Planting": [], "Stoneworking": ["Toolmaking"], "Preservation": ["Planting"],
    "Forestry": ["Planting", "Woodcutting"], "Crop Rotation": ["Preservation"],
    "Carpentry": ["Stoneworking", "Woodcutting", "Shelter Building"], "Masonry": ["Carpentry"],
    "Sanitation": ["Stoneworking"], "Waterworks": ["Planting", "Sanitation"]
}
const TECH_DETAILS = {
    "Scouting": "Available from the start. Send three settlers to survey distant land and bring back dated resource reports; no research is required.",
    "Basketry": "Woven carrying baskets improve gathering output by 20%.",
    "Hunting": "Learn coordinated hunting and tracking. Gathering yields 25% more food but consumes the same finite wildlife supply.",
    "Storage": "Unlocks storehouses, adding 200 material capacity per completed building.",
    "Education": "Unlocks schools: faster apprenticeships, more training places, child education, and 25% more research.",
    "Toolmaking": "Make basic hand tools. Opens paths to shelter building, fishing, woodcutting, and stoneworking.",
    "Shelter Building": "Unlocks construction workers and houses. Opens the storage path.",
    "Fishing": "Unlocks fishing workers and river food production.",
    "Woodcutting": "Unlocks logging workers and timber production.",
    "Planting": "Learn sowing and cultivation. Unlocks fields and crop farming.",
    "Preservation": "Drying and careful storage reduce daily food spoilage by 80%.",
    "Forestry": "Learn to replant trees. Loggers replenish some woodland alongside harvesting.",
    "Crop Rotation": "Rotate crops to preserve fertility. Fields grow 30% faster. Requires a completed field.",
    "Stoneworking": "Unlocks quarry workers and stone extraction, with a 25% tool bonus.",
    "Carpentry": "Improve timber joints and tools. Construction proceeds 25% faster.",
    "Masonry": "Unlock stone walls and build stronger, roomier houses. Each house provides 5 additional beds. Requires a storehouse.",
    "Sanitation": "Learn safe water practices. Unlocks wells and treated water.",
    "Waterworks": "Develop irrigation from wells. Fields grow another 25% faster. Requires a completed well."
}
var day: float = 0
var population: int = 30
var resources: Dictionary = {"food": 30.0, "wood": 40.0, "stone": 20.0}
var assignments: Dictionary = {"Gathering": 30, "Fishing": 0, "Logging": 0, "Quarrying": 0, "Construction": 0, "Farming": 0}
var buildings: Array = []
var armies: Array = []
var next_army_id := 1
var defense_order := "Hold settlement"
var emergency_defenders: Array = []
var battle_reports: Array = []
var technologies: Array = ["Scouting"]
var research: String = "Toolmaking"
var queued_research: String = ""
var research_progress: float = 0
var research_saved: Dictionary = {}
var forest: float = 1200
var quarry: float = 1500
var wildlife: float = 300
var starvation: float = 0
var conditions: Array = []
var events: Array = ["Your 30 settlers have arrived. Establish a reliable food supply."]
var emergency_food: bool = true
var days_per_real_day: float = 90
var revision: int = 0
var save_path := "user://settlement.json"
var has_seen_intro := false

var people: Array = []
var next_person_id := 31
var workforce_targets: Dictionary = {"Gathering": 100, "Fishing": 0, "Logging": 0, "Quarrying": 0, "Construction": 0, "Farming": 0}
var generation_targets: Dictionary = {"Gathering": 15, "Fishing": 10, "Logging": 10, "Quarrying": 5, "Construction": 30, "Farming": 30}
var automatic_workforce := false
var allow_migration := true
var allow_births := true
var migration_clock := 0.0
var birth_progress := 0.0
var happiness := 55.0
var ration_level := 1.0
var daily_food_change := 0.0
var job_roster: Dictionary = {}
var explored: Dictionary = {}
var map_format := 2
var world_origin: Array = [0.0, 0.0]
var shared_region := false
var known_civilizations: Dictionary = {}
var known_armies: Dictionary = {}
var army_sights: Array = []
var scout_mission: Dictionary = {}
var scout_missions: Array = []
var discoveries: Array = []
var exploration_revision := 0
var report_revision := 0
var food_ledger: Dictionary = {"production": 0.0, "consumption": 0.0, "spoilage": 0.0, "overflow": 0.0}
var material_production: Dictionary = {"wood": 0.0, "stone": 0.0}
const LANDMARKS = [
    {"name": "Northern stone ridge", "point": [-29.0, -22.0], "description": "Exposed stone deposits; potential future quarry site."},
    {"name": "Western woodland", "point": [-27.0, 19.0], "description": "Dense timber stands; potential future logging ground."},
    {"name": "River meadow", "point": [1.0, 26.0], "description": "Fertile riverside ground; potential future farming site."}
]

func cell_key(point: Vector2) -> String:
    return "%d:%d" % [floori((point.x + 96) / 3), floori((point.y + 96) / 3)]

func reveal_land(point: Vector2, radius: float) -> void:
    var changed := false
    for x in range(maxi(0, floori((point.x - radius + 96) / 3)), mini(64, ceili((point.x + radius + 96) / 3))):
        for z in range(maxi(0, floori((point.y - radius + 96) / 3)), mini(64, ceili((point.y + radius + 96) / 3))):
            var center := Vector2(x * 3 - 94.5, z * 3 - 94.5)
            if center.distance_to(point) <= radius:
                var key := "%d:%d" % [x, z]
                if not explored.has(key): changed = true
                explored[key] = day
    if changed: exploration_revision += 1

func workforce_capacity() -> int:
    return maxi(0, adults() - scouting_units().size() - military_ids().size())

func scouting_units() -> Array:
    var units: Array = []
    var missions := scout_missions if not scout_missions.is_empty() else ([scout_mission] if not scout_mission.is_empty() else [])
    for mission in missions:
        for id in mission.get("units", []):
            if id not in units: units.append(id)
    return units

func scout_mission_for_unit(person_id: int) -> Dictionary:
    var missions := scout_missions if not scout_missions.is_empty() else ([scout_mission] if not scout_mission.is_empty() else [])
    for mission in missions:
        if person_id in mission.get("units", []): return mission
    return {}

func mission_direction(mission: Dictionary) -> Vector2:
    var age: float = float(mission.get("progress", day - mission.started))
    var travel: float = mission.travel
    var survey_days := mission_survey_duration(mission)
    var destination := Vector2(mission.destination[0], mission.destination[1])
    if age < travel: return destination - mission_departure_point(mission)
    if age < travel + survey_days or age >= travel + survey_days + mission_return_travel(mission): return Vector2.ZERO
    return mission_return_point(mission) - destination

func mission_survey_duration(mission: Dictionary) -> float:
    return maxf(0.0, float(mission.get("survey_days", 3.0)))

func has_civilization_near(point: Vector2) -> bool:
    for contact in known_civilizations.values():
        if point.distance_to(Vector2(contact.point[0], contact.point[1])) <= 10.0: return true
    return false

func mission_position(mission: Dictionary) -> Vector2:
    var destination := Vector2(mission.destination[0], mission.destination[1])
    var age: float = float(mission.get("progress", day - mission.started))
    var travel: float = mission.travel
    if age < travel: return mission_departure_point(mission).lerp(destination, age / travel)
    var survey_days := mission_survey_duration(mission)
    if age < travel + survey_days: return destination
    return destination.lerp(mission_return_point(mission), clampf((age - travel - survey_days) / maxf(mission_return_travel(mission), 0.001), 0, 1))

func mission_departure_point(mission: Dictionary) -> Vector2:
    if mission.has("origin"): return Vector2(mission.origin[0], mission.origin[1])
    return Vector2(-4, 0)

func mission_return_travel(mission: Dictionary) -> float:
    if mission.has("origin"): return float(mission.travel)
    var destination := Vector2(mission.destination[0], mission.destination[1])
    return float(mission.travel) * clampf(1.0 - CAMP_RADIUS / maxf(destination.distance_to(Vector2(-4, 0)), 0.001), 0.0, 1.0)

func mission_return_point(mission: Dictionary) -> Vector2:
    if mission.has("origin"): return mission_departure_point(mission)
    var destination := Vector2(mission.destination[0], mission.destination[1])
    return destination.lerp(Vector2(-4, 0), mission_return_travel(mission) / float(mission.travel))

func scout_position() -> Vector2:
    return mission_position(scout_mission) if not scout_mission.is_empty() else Vector2(-4, 0)

func scout_departure_point() -> Vector2:
    return mission_departure_point(scout_mission) if not scout_mission.is_empty() else Vector2(-4, 0)

func scout_direction() -> Vector2:
    return mission_direction(scout_mission) if not scout_mission.is_empty() else Vector2.ZERO

func scout_return_travel() -> float:
    return mission_return_travel(scout_mission) if not scout_mission.is_empty() else 0.0

func scout_return_point() -> Vector2:
    return mission_return_point(scout_mission) if not scout_mission.is_empty() else Vector2(-4, 0)

func scout_remaining_days() -> float:
    return mission_remaining_days(scout_mission) if not scout_mission.is_empty() else 0.0

func mission_remaining_days(mission: Dictionary) -> float:
    if mission.is_empty(): return 0.0
    var age: float = float(mission.get("progress", day - mission.started))
    var travel: float = mission.travel
    var outbound := maxf(0.0, travel - age)
    var survey_days := mission_survey_duration(mission)
    if float(mission.get("survey_days", 3.0)) < 0.0: survey_days = 3.0
    var survey := clampf(travel + survey_days - age, 0.0, survey_days)
    var return_travel := mission_return_travel(mission)
    var returning := clampf(travel + return_travel + survey_days - age, 0.0, return_travel)
    return ((outbound + returning) / SCOUT_TRAVEL_RATE + survey) / travel_factor()

func scouting_block(destination: Vector2) -> String:
    if "Scouting" not in technologies: return "Research Scouting first."
    if destination.distance_to(Vector2(-4, 0)) <= CAMP_RADIUS: return "Choose a destination outside the civilization's camp area."
    if absf(destination.x) > 88 or absf(destination.y) > 88: return "Destination lies beyond this world view."
    var river := 10.0 + sin((destination.y + float(world_origin[1])) * 0.095) * 3.0
    if (shared_region and destination.x + float(world_origin[0]) > river - 4.0) or (not shared_region and destination.x > 4): return "Crossing the river requires transport; survey the western bank for now."
    var cost := scout_food_cost(destination)
    if resources.food < cost: return "This trip needs %d food for its distance and duration." % cost
    if adults() < 3: return "Three working-age settlers are needed."
    var units: Array = []
    for person in people:
        if person.age >= 16 and person.age < 65 and person.training.is_empty() and int(person.id) not in military_ids() and int(person.id) not in scouting_units():
            units.append(int(person.id))
            if units.size() == 3: break
    if units.size() < 3: return "Three adults outside training are needed."
    return ""

func send_scouts(destination: Vector2) -> String:
    var blocked := scouting_block(destination)
    if not blocked.is_empty(): return blocked
    var units: Array = []
    for person in people:
        if person.age >= 16 and person.age < 65 and person.training.is_empty() and int(person.id) not in military_ids() and int(person.id) not in scouting_units():
            units.append(int(person.id))
            if units.size() == 3: break
    var cost := scout_food_cost(destination)
    resources.food -= cost
    var origin := Vector2(-4, 0) + (destination - Vector2(-4, 0)).normalized() * CAMP_RADIUS
    var mission := {"units": units, "origin": [origin.x, origin.y], "destination": [destination.x, destination.y], "started": day, "progress": 0.0, "travel": maxf(0.001, destination.distance_to(origin) / 2), "food": cost, "survey_days": -1.0, "surveyed": false}
    scout_missions.append(mission)
    scout_mission = scout_missions[0]
    clamp_assignments()
    announce("Three settlers departed on a scouting expedition with %d food." % cost)
    return "Scouts dispatched with %d food. Their return takes approximately %.0f game days." % [cost, scout_remaining_days()]

func scout_food_cost(destination: Vector2) -> int:
    var origin := Vector2(-4, 0) + (destination - Vector2(-4, 0)).normalized() * CAMP_RADIUS
    var outbound := maxf(0.001, destination.distance_to(origin) / 2.0)
    var returning := outbound * clampf(1.0 - CAMP_RADIUS / maxf(destination.distance_to(Vector2(-4, 0)), 0.001), 0.0, 1.0)
    # Three adults consume one food per 30 days at normal rations; pack their round-trip needs.
    var expected_days := (outbound + returning) / SCOUT_TRAVEL_RATE + 3.0
    return maxi(1, ceili(expected_days / 30.0 * ration_level))

func update_exploration(dt: float = 0.0) -> void:
    reveal_land(Vector2(-4, 0), 21)
    for sight in army_sights: reveal_land(Vector2(sight[0], sight[1]), 5)
    if scout_missions.is_empty() and not scout_mission.is_empty(): scout_missions.append(scout_mission)
    if scout_missions.is_empty(): return
    var returned: Array = []
    var remaining_time := dt * travel_factor()
    for mission in scout_missions:
        var progress: float = float(mission.get("progress", day - mission.started - dt))
        var travel: float = mission.travel
        var mission_remaining := remaining_time
        var returning_travel := mission_return_travel(mission)
        var survey_days := float(mission.get("survey_days", 3.0))
        # Split at phase boundaries so a large time step does not accelerate surveying.
        if progress < travel:
            var outbound_time := minf(mission_remaining, (travel - progress) / SCOUT_TRAVEL_RATE)
            progress += outbound_time * SCOUT_TRAVEL_RATE
            mission_remaining -= outbound_time
        if progress >= travel and survey_days < 0.0:
            survey_days = 3.0 if has_civilization_near(Vector2(mission.destination[0], mission.destination[1])) else 0.0
            mission.survey_days = survey_days
        if progress >= travel and progress < travel + survey_days:
            var survey_time := minf(mission_remaining, travel + survey_days - progress)
            progress += survey_time
            mission_remaining -= survey_time
        if progress >= travel + survey_days:
            progress = minf(travel + survey_days + returning_travel, progress + mission_remaining * SCOUT_TRAVEL_RATE)
        mission.progress = progress
        reveal_land(mission_position(mission), 7)
        var age: float = float(mission.get("progress", day - mission.started))
        if age >= mission.travel and not mission.surveyed and survey_days > 0.0:
            mission.surveyed = true
            announce("Scouts found a civilization and began their on-site survey.")
        elif age >= mission.travel and not mission.surveyed:
            mission.surveyed = true
            announce("Scouts found no civilization at the destination and are returning.")
        if age >= mission.travel + survey_days + returning_travel:
            var report_point := Vector2(mission.destination[0], mission.destination[1])
            returned.append(mission)
            for landmark in LANDMARKS:
                var point := Vector2(landmark.point[0], landmark.point[1])
                if point.distance_to(report_point) < 9 and landmark.name not in discoveries:
                    discoveries.append(landmark.name)
                    announce("Scouts discovered %s. %s" % [landmark.name, landmark.description])
    for mission in returned: scout_missions.erase(mission)
    scout_mission = scout_missions[0] if not scout_missions.is_empty() else {}
    if not returned.is_empty():
        report_revision += 1
        exploration_revision += 1
        for mission in returned: announce("Scouts returned with their report. Three settlers are available again.")
    for mission in scout_missions: reveal_land(mission_position(mission), 7)

func land_report(point: Vector2) -> String:
    var key := cell_key(point)
    var description := "Unexplored land" if not explored.has(key) else "Known land · last seen day %.0f" % (float(explored[key]) + 1)
    if point.distance_to(Vector2(-4, 0)) <= 21: description = "Home region · live information"
    elif has_live_sight(point): description = "Currently observed by your expedition"
    for contact in known_civilizations.values():
        if point.distance_to(Vector2(contact.point[0], contact.point[1])) <= 10:
            description += "\n%s · %d people · seen %.1f days ago" % [contact.name, contact.population, maxf(0.0, day - float(contact.last_seen))]
    for report in known_armies.values():
        if point.distance_to(Vector2(report.point[0], report.point[1])) <= 7:
            if report.get("intel_scouted", false):
                description += "\n%s: %d %s · scouted day %.1f" % [report.commander, report.count, report.unit, report.last_scouted]
            else: description += "\nEnemy army · troops unknown · seen %.1f days ago" % maxf(0.0, day - float(report.last_seen))
    for landmark in LANDMARKS:
        var location := Vector2(landmark.point[0], landmark.point[1])
        if location.distance_to(point) < 9 and landmark.name in discoveries: description += "\n" + landmark.name
    if not scout_missions.is_empty(): description += "\n%d scouting parties are away." % scout_missions.size()
    elif not scout_mission.is_empty(): description += "\n1 scouting party is away."
    else: description += "\nSelect land, then send three settlers to scout. Food cost depends on trip duration."
    return "Region (%d, %d)\n%s" % [roundi(point.x), roundi(point.y), description]


func _init() -> void:
    seed_people()
    reveal_land(Vector2(-4, 0), 21)

func seed_people() -> void:
    people.clear()
    for i in range(population):
        var person := {"id": i + 1, "age": 18.0 + (i % 18), "profession": "General", "skill": 0.0, "training": "", "training_progress": 0.0, "career": ""}
        person["death_age"] = lifespan_for(person.id)
        people.append(person)
    next_person_id = population + 1

func lifespan_for(person_id: int) -> float:
    # Stable per-person variation keeps saved citizens' lifespan consistent.
    var offset := posmod(person_id * 37 + 11, 101) / 100.0
    return ELDER_DEATH_AGE_MIN + (ELDER_DEATH_AGE_MAX - ELDER_DEATH_AGE_MIN) * offset

func ensure_lifespan(person: Dictionary) -> void:
    if not person.has("death_age"):
        person["death_age"] = lifespan_for(int(person.get("id", 0)))

func adults() -> int:
    var count := 0
    for person in people:
        if person.age >= 16 and person.age < 65: count += 1
    return count

func children() -> int:
    var count := 0
    for person in people:
        if person.age < 16: count += 1
    return count

func food_need() -> float:
    var deployed := 0
    for army in armies:
        if army.status in ["Marching", "Fighting", "Returning"]: deployed += army.soldiers.size()
    return maxf(0, population - children() * 0.5 - deployed - scouting_units().size()) / 90.0 * ration_level

func happiness_influences() -> Array:
    var factors: Array = [{"name": "Community spirit", "value": 70.0, "detail": "The starting baseline for this settlement."}]
    var reserve_days := float(resources.food) / maxf(0.001, (population - children() * 0.5) / 90.0)
    var food_value := 10.0 if reserve_days >= 90 else 0.0 if reserve_days >= 45 else -10.0 if reserve_days >= 27 else -20.0 if resources.food > 0 else -40.0
    factors.append({"name": "Food reserves", "value": food_value, "detail": "%.0f days at normal rations. Build reserves and reliable production." % reserve_days})
    factors.append({"name": "Ration policy", "value": -15.0 if ration_level < 1 else 5.0 if ration_level > 1 else 0.0, "detail": "Reduced rations save food but strain people; generous rations use more food."})
    factors.append({"name": "Water quality", "value": -15.0 if completed("Well") == 0 else 0.0, "detail": "Untreated water. Research Sanitation and build a well." if completed("Well") == 0 else "A completed well supplies treated water."})
    factors.append({"name": "Crowding", "value": -minf(25.0, maxf(0, population - housing()) * 4.0), "detail": "%d people / %d shelter places." % [population, housing()]})
    var beds := completed("House") * (15 if "Masonry" in technologies else 10) + military_housed()
    var missing_beds := maxi(0, population - beds)
    factors.append({"name": "Bedding & comfort", "value": -10.0 * missing_beds / maxf(1, population), "detail": "%d settlers lack permanent beds. Houses and occupied barracks include bedding; starting tents do not." % missing_beds})
    var winter: bool = int(day / 90) % 4 == 3
    factors.append({"name": "Living conditions", "value": -8.0 * missing_beds / maxf(1, population) if winter else 0.0, "detail": "Winter exposes temporary shelters to cold." if winter else "No seasonal shelter penalty."})
    factors.append({"name": "Prolonged hardship", "value": -minf(15.0, starvation * 0.5), "detail": "Starvation leaves lasting strain; recovering food gradually relieves it."})
    factors.append({"name": "Education", "value": 5.0 if completed("School") > 0 else 0.0, "detail": "A school supports the community and prepares the next generation."})
    return factors

func refresh_happiness() -> void:
    happiness = 0
    for factor in happiness_influences(): happiness += factor.value
    happiness = clampf(happiness, 0, 100)

func target_total(targets: Dictionary) -> int:
    var count := 0
    for value in targets.values(): count += int(value)
    return count

func set_target(job: String, value: int, future: bool = false) -> void:
    if not future and not job_unlocked(job): return
    var targets := generation_targets if future else workforce_targets
    targets[job] = clampi(value, 0, 100 - target_total(targets) + int(targets[job]))
    if automatic_workforce and not future: apply_targets()

func job_unlocked(job: String) -> bool:
    return JOB_TECH[job].is_empty() or JOB_TECH[job] in technologies

func building_block(kind: String) -> String:
    if not BUILDINGS.has(kind): return "Unknown building."
    if not job_unlocked("Construction"): return "Requires Shelter Building."
    var required: String = {"Field": "Planting", "Well": "Sanitation", "School": "Education", "Storehouse": "Storage", "Training Grounds": "Toolmaking", "Barracks": "Shelter Building", "Palisade": "Carpentry", "Wall": "Masonry"}.get(kind, "")
    if not required.is_empty() and required not in technologies: return "Requires " + required + "."
    var missing := PackedStringArray()
    for resource in BUILDINGS[kind]:
        if resource == "work": continue
        if float(resources.get(resource, 0.0)) < float(BUILDINGS[kind][resource]):
            missing.append("%s (need %.1f, have %.1f)" % [resource, BUILDINGS[kind][resource], resources.get(resource, 0.0)])
    return "Missing resources: " + "; ".join(missing) if not missing.is_empty() else ""

func apply_targets() -> void:
    var total := workforce_capacity()
    var allocated := 0
    var remainders: Array = []
    for job in JOBS:
        var desired := total * float(workforce_targets[job]) / 100.0 if job_unlocked(job) else 0.0
        assignments[job] = int(desired)
        allocated += int(desired)
        if job_unlocked(job): remainders.append({"job": job, "fraction": desired - floorf(desired)})
    remainders.sort_custom(func(a, b): return a.fraction > b.fraction)
    var eligible_percent := 0
    for job in JOBS:
        if job_unlocked(job): eligible_percent += int(workforce_targets[job])
    var remaining := int(round(total * eligible_percent / 100.0)) - allocated
    for i in range(remaining): assignments[remainders[i].job] += 1

func clamp_assignments() -> void:
    var remaining := workforce_capacity()
    for job in JOBS:
        assignments[job] = mini(int(assignments[job]), remaining) if job_unlocked(job) else 0
        remaining -= int(assignments[job])

func prepare_roster(work: Dictionary) -> void:
    job_roster.clear()
    var available: Array = []
    for person in people:
        if person.age >= 16 and person.age < 65 and int(person.id) not in scouting_units() and int(person.id) not in military_ids(): available.append(person)
    # Reserve specialists for their matching jobs before filling general duties.
    for job in JOBS:
        job_roster[job] = []
        for person in available.duplicate():
            if person.profession == job and job_roster[job].size() < int(work[job]):
                job_roster[job].append(person)
                available.erase(person)
    for job in JOBS:
        while job_roster[job].size() < int(work[job]) and not available.is_empty():
            job_roster[job].append(available.pop_front())

func labor(job: String) -> float:
    var amount := 0.0
    for person in job_roster.get(job, []):
        amount += (1.0 + float(person.skill) if person.profession == job else 1.0) * (0.75 if not person.training.is_empty() else 1.0)
    return amount

func start_training(job: String) -> String:
    if not job_unlocked(job): return "Requires " + JOB_TECH[job] + "."
    var enrolled := 0
    for person in people:
        if not person.training.is_empty(): enrolled += 1
    var slots := 4 if completed("School") > 0 else 2
    if enrolled >= slots: return "All %d training places are occupied." % slots
    if resources.food < 1 or resources.wood < 2: return "Training requires 1 food and 2 wood."
    var candidates: Array = []
    for person in people:
        if person.age >= 16 and person.age < 65 and person.training.is_empty() and person.profession != job and int(person.id) not in scouting_units() and int(person.id) not in military_ids():
            candidates.append(person)
    candidates.sort_custom(func(a, b): return a.profession == "General" and b.profession != "General")
    if candidates.is_empty(): return "No eligible adult available for retraining."
    var person: Dictionary = candidates[0]
    person.training = job
    person.training_progress = 0.0
    resources.food -= 1
    resources.wood -= 2
    announce("Settler %d began %s training." % [person.id, job.to_lower()])
    return "Training started: 60 game days, 25% less work while learning."

func next_career() -> String:
    var best := "General"
    var score := 0.0
    for job in JOBS:
        var count := 0
        for person in people:
            if person.career == job or (person.career.is_empty() and person.profession == job): count += 1
        var deficit := population * float(generation_targets[job]) / 100.0 - count
        if deficit > score:
            best = job
            score = deficit
    return best

func update_population(dt: float) -> void:
    for person in people.duplicate():
        ensure_lifespan(person)
        var was_child: bool = person.age < 16
        person.age += dt / 360.0
        if person.age >= float(person.death_age):
            people.erase(person)
            announce("A settler died of old age at %.1f." % person.age)
            continue
        if not person.training.is_empty():
            person.training_progress += dt * (1.5 if completed("School") > 0 else 1.0)
            if person.training_progress >= 60:
                person.profession = person.training
                person.skill = 0.30
                person.training = ""
                person.training_progress = 0.0
                announce("Settler %d qualified in %s." % [person.id, person.profession.to_lower()])
        if person.age >= 12 and person.age < 16 and completed("School") > 0 and person.career != "General" and not person.career.is_empty() and job_unlocked(person.career):
            person.profession = person.career
            person.skill = minf(0.30, float(person.skill) + dt / 1800.0)
        if was_child and person.age >= 16:
            announce("A young settler joined the adult workforce.")
    for job in job_roster:
        for person in job_roster[job]:
            if person.profession == job: person.skill = minf(0.60, float(person.skill) + dt * 0.0003)
    population = people.size()
    refresh_happiness()
    migration_clock += dt
    if migration_clock >= 90:
        migration_clock -= 90
        if allow_migration and happiness >= 60 and resources.food >= population * 0.75 and housing() > population:
            var arrivals := mini(2 if population < 60 else 1, housing() - population)
            for i in range(arrivals):
                var migrant := {"id": next_person_id, "age": 20.0 + next_person_id % 15, "profession": "General", "skill": 0.0, "training": "", "training_progress": 0.0, "career": ""}
                migrant["death_age"] = lifespan_for(next_person_id)
                people.append(migrant)
                next_person_id += 1
            announce("%d migrants joined the settlement." % arrivals)
    if allow_births and happiness >= 60 and housing() > people.size() and resources.food >= population * 0.5:
        birth_progress += adults() * 0.035 / 360.0 * dt
        if birth_progress >= 1:
            birth_progress -= 1
            var career := next_career()
            var newborn := {"id": next_person_id, "age": 0.0, "profession": "General", "skill": 0.0, "training": "", "training_progress": 0.0, "career": career}
            newborn["death_age"] = lifespan_for(next_person_id)
            people.append(newborn)
            next_person_id += 1
            announce("A child was born. The next generation is growing.")
    population = people.size()
    advance_armies(0)
    if automatic_workforce: apply_targets()
    else: clamp_assignments()

func capacity() -> float:
    return 180.0 + completed("Storehouse") * 200.0

func housing() -> int:
    return 30 + completed("House") * (15 if "Masonry" in technologies else 10) + military_housed()

func completed(kind: String) -> int:
    var count := 0
    for b in buildings:
        if b.kind == kind and b.progress >= 1.0: count += 1
    return count

func workers_used() -> int:
    var result := 0
    for value in assignments.values(): result += int(value)
    return result

func assign(job: String, count: int) -> void:
    if not job_unlocked(job): return
    automatic_workforce = false
    var available := workforce_capacity() - workers_used() + int(assignments[job])
    var assigned := clampi(count, 0, available)
    # An explicit order to add builders or quarry workers overrides their food diversion.
    if emergency_food and job in ["Construction", "Quarrying"] and assigned > int(assignments[job]):
        emergency_food = false
        announce("Manual workforce order: food-shortage diversion disabled.")
    assignments[job] = assigned
    prepare_roster(effective_assignments())

func announce(message: String) -> void:
    events.push_front(message)
    if events.size() > 24: events.resize(24)

func order_build(kind: String, q: int, r: int) -> String:
    if not BUILDINGS.has(kind): return "Unknown building."
    var center := Vector2(3.0 * q, sqrt(3.0) * 2.0 * (r + q * 0.5))
    if center.distance_to(Vector2(-4, 0)) > CAMP_RADIUS or center.x > 4: return "Choose land inside the starting clearing."
    if center.distance_to(Vector2(-6, 0)) < 3 or center.distance_to(Vector2(-2, 5)) < 2 or center.distance_to(Vector2(-11, 5.7)) < 2:
        return "The starting camp occupies this site."
    for b in buildings:
        if b.q == q and b.r == r: return "This hex already has a building."
    if kind == "Field" and not "Planting" in technologies: return "Research Planting first."
    if kind == "School" and "Education" not in technologies: return "Research Education first."
    if kind == "Well" and not "Sanitation" in technologies: return "Research Sanitation first."
    var blocked := building_block(kind)
    if not blocked.is_empty(): return blocked
    var cost: Dictionary = BUILDINGS[kind]
    for resource in cost:
        if resource != "work": resources[resource] -= cost[resource]
    buildings.append({"kind": kind, "q": q, "r": r, "progress": 0.0, "growth": 0.0})
    revision += 1
    announce("%s commissioned; materials reserved at the site." % kind)
    return ""

func research_block(tech: String, allow_current: bool = false) -> String:
    if not TECHNOLOGIES.has(tech): return "Unknown technology."
    var missing := PackedStringArray()
    for prerequisite in PREREQUISITES[tech]:
        if prerequisite not in technologies and not (allow_current and prerequisite == research):
            missing.append(prerequisite)
    if not missing.is_empty(): return "Requires: " + ", ".join(missing)
    var facility: String = {"Crop Rotation": "Field", "Masonry": "Storehouse", "Waterworks": "Well"}.get(tech, "")
    if not facility.is_empty() and completed(facility) == 0: return "Requires a completed " + facility + "."
    return ""

func choose_research(tech: String, queue_next: bool = false) -> String:
    if tech in technologies: return "Already learned."
    var blocked := research_block(tech, queue_next)
    if not blocked.is_empty(): return blocked
    if tech == research: return "Already researching this technology."
    if queue_next and not research.is_empty():
        queued_research = tech
        return "Queued " + tech + "."
    if not research.is_empty(): research_saved[research] = research_progress
    research = tech
    research_progress = float(research_saved.get(tech, 0.0))
    if queued_research == tech: queued_research = ""
    return "Researching " + tech + ". Previous progress is retained."

func effective_assignments() -> Dictionary:
    var work := assignments.duplicate()
    for job in JOBS:
        if not job_unlocked(job): work[job] = 0
    if emergency_food and resources.food < population * 0.5:
        work.Gathering += work.Construction + work.Quarrying
        work.Construction = 0
        work.Quarrying = 0
    return work

func advance(days: float, interrupt: bool = false) -> float:
    var elapsed := 0.0
    while elapsed < days:
        var step := minf(0.25, days - elapsed)
        var before := conditions.duplicate()
        var reports_before := report_revision
        tick(step)
        elapsed += step
        if interrupt and report_revision != reports_before:
            announce("Time advance interrupted: scouts have news.")
            break
        if interrupt and conditions != before and ("Starving" in conditions or "Food shortage" in conditions):
            announce("Time advance interrupted: food needs attention.")
            break
    return elapsed

func tick(dt: float) -> void:
    var previous_conditions := conditions.duplicate()
    var food_before: float = resources.food
    var old_season := int(day / 90) % 4
    day += dt
    var new_season := int(day / 90) % 4
    if new_season != old_season:
        announce("%s arrived. %s" % [["Spring", "Summer", "Autumn", "Winter"][new_season], season_description()])
        report_revision += 1
    advance_armies(dt)
    update_exploration(dt)
    if automatic_workforce: apply_targets()
    clamp_assignments()
    var work := effective_assignments()
    prepare_roster(work)
    # Rates include travel and rest; nobody contributes a full day of labor.
    var season := int(day / 90.0) % 4
    var gathered := minf(wildlife, labor("Gathering") * dt * (0.11 * [1.05, 1.15, 1.0, 0.5][season]) * (1.2 if "Basketry" in technologies else 1.0) * (1.25 if "Hunting" in technologies else 1.0))
    wildlife = minf(300, wildlife - gathered + [0.30, 0.24, 0.18, 0.08][season] * dt)
    var food_produced: float = gathered + labor("Fishing") * dt * (0.14 * [1.0, 1.15, 0.9, 0.55][season])
    resources.food += food_produced
    var timber := minf(forest, labor("Logging") * dt * 0.12 * (0.8 if season == 3 else 1.0))
    forest -= timber
    if "Forestry" in technologies: forest = minf(1200, forest + labor("Logging") * dt * 0.04 * (0.0 if season == 3 else 1.25 if season == 0 else 1.0))
    resources.wood += timber
    var stone := minf(quarry, labor("Quarrying") * dt * 0.09 * (0.75 if season == 3 else 1.0) * (1.25 if "Stoneworking" in technologies else 1.0))
    quarry -= stone
    resources.stone += stone
    var fields := completed("Field")
    for b in buildings:
        if b.kind == "Field" and b.progress >= 1 and fields > 0:
            if season != 3:
                b.growth += labor("Farming") / fields * dt / 165.0 * [1.1, 1.2, 0.85, 0.0][season] * (1.3 if "Crop Rotation" in technologies else 1.0) * (1.25 if "Waterworks" in technologies and completed("Well") > 0 else 1.0)
                if b.growth >= 1:
                    b.growth -= 1
                    resources.food += 70
                    food_produced += 70
                    announce("A field harvest delivered 70 food.")
    var budget := labor("Construction") * dt * 0.35 * (0.75 if season == 3 else 1.0) * (1.25 if "Carpentry" in technologies else 1.0)
    for b in buildings:
        if b.progress < 1 and budget > 0:
            var needed: float = (1 - b.progress) * BUILDINGS[b.kind].work
            var used := minf(budget, needed)
            b.progress = minf(1, b.progress + used / BUILDINGS[b.kind].work)
            budget -= used
            if b.progress >= 1:
                revision += 1
                announce("%s completed." % b.kind)
    if not research.is_empty() and research_block(research).is_empty():
        research_progress += dt / 90.0 * (1.25 if completed("School") > 0 else 1.0)
        if research_progress >= TECHNOLOGIES[research]:
            technologies.append(research)
            announce("%s learned." % research)
            research_saved.erase(research)
            research = ""
            research_progress = 0
            if not queued_research.is_empty() and research_block(queued_research).is_empty():
                research = queued_research
                research_progress = float(research_saved.get(research, 0.0))
                queued_research = ""
    var consumed := minf(float(resources.food), food_need() * dt)
    resources.food -= consumed
    var before_spoilage: float = resources.food
    resources.food *= pow(0.9996 if "Preservation" in technologies else 0.998, dt * [1.0, 1.35, 0.9, 0.55][season])
    var spoiled: float = before_spoilage - resources.food
    var food_overflow := 0.0
    var stored: float = resources.food + resources.wood + resources.stone
    if stored > capacity():
        var excess := stored - capacity()
        # Overflow remains uncollected at source for durable resources.
        var return_wood := minf(excess, timber)
        resources.wood -= return_wood
        forest += return_wood
        timber -= return_wood
        excess -= return_wood
        var return_stone := minf(excess, stone)
        resources.stone -= return_stone
        quarry += return_stone
        stone -= return_stone
        excess -= return_stone
        food_overflow = minf(float(resources.food), excess)
        resources.food = maxf(0, resources.food - excess)
    if resources.food <= 0.001: starvation += dt
    else: starvation = maxf(0, starvation - dt)
    if starvation >= 30 and population > 1:
        people.pop_back()
        population = people.size()
        clamp_assignments()
        starvation -= 30
        announce("A settler was lost to prolonged starvation.")
    update_population(dt)
    if dt > 0:
        daily_food_change = (resources.food - food_before) / dt
        food_ledger = {"production": food_produced / dt, "consumption": consumed / dt, "spoilage": spoiled / dt, "overflow": food_overflow / dt}
        material_production = {"wood": timber / dt, "stone": stone / dt}
    conditions = []
    if resources.food <= 0.001: conditions.append("Starving")
    elif resources.food < population / 3.0: conditions.append("Food shortage")
    if resources.food + resources.wood + resources.stone >= capacity() - 1: conditions.append("Storage full")
    if housing() < population: conditions.append("Overcrowded")
    if completed("Well") == 0: conditions.append("Untreated water")
    if happiness < 40: conditions.append("Unrest")
    if conditions.is_empty(): conditions.append("Stable")
    if previous_conditions != conditions and dt > 0:
        announce("Settlement condition: %s." % " · ".join(conditions))

func snapshot() -> Dictionary:
    return {"version": 1, "map_format": map_format, "has_seen_intro": has_seen_intro, "world_origin": world_origin, "shared_region": shared_region, "known_civilizations": known_civilizations, "known_armies": known_armies, "army_sights": army_sights, "armies": armies, "next_army_id": next_army_id, "defense_order": defense_order, "emergency_defenders": emergency_defenders, "battle_reports": battle_reports, "ration_level": ration_level, "explored": explored, "scout_mission": scout_mission, "scout_missions": scout_missions, "discoveries": discoveries, "people": people, "next_person_id": next_person_id, "workforce_targets": workforce_targets, "generation_targets": generation_targets, "automatic_workforce": automatic_workforce, "allow_migration": allow_migration, "allow_births": allow_births, "migration_clock": migration_clock, "birth_progress": birth_progress, "day": day, "population": population, "resources": resources, "material_production": material_production, "assignments": assignments, "buildings": buildings, "technologies": technologies, "research": research, "queued_research": queued_research, "research_progress": research_progress, "research_saved": research_saved, "forest": forest, "quarry": quarry, "wildlife": wildlife, "starvation": starvation, "events": events, "emergency_food": emergency_food, "days_per_real_day": days_per_real_day, "saved_at": Time.get_unix_time_from_system()}

func save_game() -> void:
    if save_path.is_empty(): return
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file: file.store_string(JSON.stringify(snapshot()))

func restore_snapshot(data: Dictionary) -> void:
    # Only known simulation fields can be restored; networking and file paths stay local.
    var old_buildings := JSON.stringify(buildings)
    var old_explored := JSON.stringify(explored)
    for key in snapshot():
        if key not in ["version", "saved_at"] and data.has(key): set(key, data[key])
    if scout_missions.is_empty() and not scout_mission.is_empty(): scout_missions = [scout_mission]
    scout_mission = scout_missions[0] if not scout_missions.is_empty() else {}
    unlock_starting_scouting()
    sanitize_army_intel()
    if int(data.get("map_format", 1)) < 2: migrate_map()
    population = people.size()
    clamp_assignments()
    prepare_roster(effective_assignments())
    tick(0)
    if old_buildings != JSON.stringify(buildings): revision += 1
    if old_explored != JSON.stringify(explored): exploration_revision += 1

func load_game() -> void:
    if save_path.is_empty() or not FileAccess.file_exists(save_path): return
    var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    if not data is Dictionary or data.get("version", 0) != 1: return
    for key in data:
        if key not in ["version", "saved_at"]: set(key, data[key])
    if scout_missions.is_empty() and not scout_mission.is_empty(): scout_missions = [scout_mission]
    scout_mission = scout_missions[0] if not scout_missions.is_empty() else {}
    unlock_starting_scouting()
    sanitize_army_intel()
    if int(data.get("map_format", 1)) < 2: migrate_map()
    if not data.has("people"): seed_people()
    population = people.size()
    clamp_assignments()
    var absent := maxf(0, Time.get_unix_time_from_system() - float(data.saved_at))
    advance(absent / 86400.0 * days_per_real_day)
    revision += 1
    if absent > 60: announce("Essential work continued during your absence (%.1f game days)." % (absent / 86400 * days_per_real_day))

func sanitize_army_intel() -> void:
    var sanitized: Dictionary = {}
    for key in known_armies:
        sanitized[key] = Warfare.public_enemy_report(known_armies[key])
    known_armies = sanitized

func unlock_starting_scouting() -> void:
    # Older solo saves, resumed worlds and incoming snapshots may still lock it.
    if "Scouting" not in technologies:
        technologies = technologies.duplicate()
        technologies.append("Scouting")
    research_saved.erase("Scouting")
    if queued_research == "Scouting": queued_research = ""
    if research == "Scouting":
        research = ""
        research_progress = 0
        if not queued_research.is_empty() and queued_research not in technologies and research_block(queued_research).is_empty():
            var next_technology := queued_research
            queued_research = ""
            choose_research(next_technology)

func military_ids() -> Array:
    var ids: Array = emergency_defenders.duplicate()
    for army in armies:
        for id in army.soldiers:
            if id not in ids: ids.append(id)
    return ids

func advance_armies(days: float) -> void:
    var adults_by_id: Dictionary = {}
    for person in people:
        if person.age >= 16 and person.age < 65: adults_by_id[int(person.id)] = true
    var trainees := 0
    for army in armies:
        if army.status == "Training": trainees += army.soldiers.size()
    var training_rate := minf(1.0, completed("Training Grounds") * 6.0 / maxf(1, trainees))
    for army in armies.duplicate():
        for id in army.soldiers.duplicate():
            if not adults_by_id.has(int(id)): army.soldiers.erase(id)
        if army.soldiers.is_empty():
            armies.erase(army)
            continue
        if army.status == "Training":
            army.training += days * training_rate
            if army.training >= Warfare.UNITS[army.unit].days:
                army.status = "Ready"
                announce("%s's %s completed training." % [army.commander, army.unit.to_lower()])
        if army.status in ["Ready", "Training", "Recovering"]:
            army.morale = minf(100, float(army.morale) + days * (2.0 if resources.food > 0 else 0.0))
            if army.status == "Recovering" and army.morale >= 60: army.status = "Ready"
    for id in emergency_defenders.duplicate():
        if not adults_by_id.has(int(id)): emergency_defenders.erase(id)

func fortification_bonus() -> float:
    var timber := minf(0.4, completed("Palisade") * 0.25)
    var stone := minf(0.6, completed("Wall") * 0.2)
    return minf(0.8, timber + stone)

func military_capacity() -> int:
    return completed("Barracks") * 12

func military_housed() -> int:
    var count := 0
    for army in armies: count += army.soldiers.size()
    return mini(count, military_capacity())

func has_live_sight(point: Vector2) -> bool:
    if point.distance_to(Vector2(-4, 0)) <= 21: return true
    for mission in scout_missions:
        if point.distance_to(mission_position(mission)) <= 7: return true
    if scout_missions.is_empty() and not scout_mission.is_empty() and point.distance_to(scout_position()) <= 7: return true
    for sight in army_sights:
        if point.distance_to(Vector2(sight[0], sight[1])) <= 5: return true
    return false

func migrate_map() -> void:
    var migrated: Dictionary = {}
    for key in explored:
        var pieces := str(key).split(":")
        if pieces.size() == 2: migrated["%d:%d" % [int(pieces[0]) + 16, int(pieces[1]) + 16]] = explored[key]
    explored = migrated
    map_format = 2

func season_description() -> String:
    return ["New forage and woodland recover faster; fields begin growing.", "Gathering, fishing and crops flourish; food spoils faster in the heat.", "Field growth slows; fishing falls and winter reserves matter.", "Fields stop growing; food gathering, fishing and outdoor work slow. Poor housing lowers happiness."][int(day / 90) % 4]

func travel_factor() -> float:
    return [0.9, 1.0, 0.85, 0.65][int(day / 90) % 4]

# The simulation's first day begins at 08:00. Fractional days are shared/saved
# already, so lighting never runs on a separate client or wall-clock timer.
func day_phase() -> float:
    return fposmod(day + 1.0 / 3.0, 1.0)

func daylight_hours() -> Vector2:
    return [Vector2(6, 18), Vector2(5, 19), Vector2(6.5, 17.5), Vector2(7.5, 16.5)][int(day / 90) % 4]

func daylight_strength() -> float:
    var hour := day_phase() * 24.0
    var hours := daylight_hours()
    return smoothstep(hours.x - 0.75, hours.x + 1.0, hour) * (1.0 - smoothstep(hours.y - 1.0, hours.y + 0.75, hour))

func is_night() -> bool:
    var hour := day_phase() * 24.0
    var hours := daylight_hours()
    return hour < hours.x or hour >= hours.y

func time_of_day() -> String:
    var minutes := int(day_phase() * 1440.0)
    return "%02d:%02d" % [minutes / 60, minutes % 60]
