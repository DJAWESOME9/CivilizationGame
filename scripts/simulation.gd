extends RefCounted

const Warfare = preload("res://scripts/warfare.gd")

# Saved mission travel/progress retain their original units. Only movement
# advances faster; the three-day survey still follows the seasonal world clock.
const SCOUT_TRAVEL_RATE := 3.0
const BASE_RESEARCH_POINTS_PER_DAY := 1.0
const CAMP_RADIUS := 12.0
const PREGNANCY_DAYS := 270.0
const LATE_PREGNANCY_DAYS := 90.0
const BIRTH_RECOVERY_DAYS := 60.0
const ELDER_DEATH_AGE_MIN := 65.0
const ELDER_DEATH_AGE_MAX := 75.0

const STARTING_OBJECTS = {
    "tent_east": {"kind": "Starting tent", "point": [-2.0, 5.0], "radius": 2.2, "work": 6.0, "wood": 3.0, "stone": 0.0},
    "tent_west": {"kind": "Starting tent", "point": [-11.0, 5.7], "radius": 2.2, "work": 6.0, "wood": 3.0, "stone": 0.0},
    "cache": {"kind": "Supply cache", "point": [-6.0, 0.0], "radius": 1.9, "work": 8.0, "wood": 5.0, "stone": 0.0},
    "cart_west": {"kind": "Cart", "point": [-8.5, 2.6], "radius": 1.9, "work": 5.0, "wood": 4.0, "stone": 0.0},
    "cart_east": {"kind": "Cart", "point": [0.5, 3.5], "radius": 1.9, "work": 5.0, "wood": 4.0, "stone": 0.0},
    "hearth": {"kind": "Campfire", "point": [-3.0, 1.5], "radius": 1.0, "work": 3.0, "wood": 1.0, "stone": 2.0}
}
# Missing entries mean intact, including in older saves. Completed jobs stay saved.
var camp_dismantling: Dictionary = {}

const JOBS = ["Gathering", "Fishing", "Logging", "Quarrying", "Construction", "Farming"]
const BUILDINGS = {
    "Carpenter Workshop": {"wood": 30.0, "stone": 12.0, "work": 45.0},
    "Bathhouse": {"wood": 24.0, "stone": 32.0, "work": 55.0},
    "Pottery Workshop": {"wood": 20.0, "stone": 16.0, "work": 35.0},
    "Boatyard": {"wood": 36.0, "stone": 8.0, "work": 45.0},
    "Archive": {"wood": 32.0, "stone": 24.0, "work": 55.0},
    "Town Hall": {"wood": 28.0, "stone": 10.0, "work": 40.0},
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
# Maximum effective construction labor assigned to one site. Any remaining
# builders continue to the next unfinished site in placement order.
const BUILDING_WORKER_CAPS = {
    "Carpenter Workshop": 6.0, "Bathhouse": 6.0,
    "Pottery Workshop": 5.0, "Boatyard": 6.0, "Archive": 6.0,
    "Town Hall": 6.0, "House": 4.0, "Storehouse": 6.0, "Field": 3.0, "Well": 5.0,
    "School": 7.0, "Training Grounds": 5.0, "Barracks": 6.0,
    "Palisade": 5.0, "Wall": 4.0
}
const TECHNOLOGIES = {
    "Joinery": 180.0,
    "Pottery": 100.0, "Boatbuilding": 180.0, "River Navigation": 240.0,
    "Archery": 140.0, "Military Organization": 100.0, "Writing": 220.0,
    "Community Organization": 60.0,
    "Scouting": 0.0,
    "Basketry": 40.0, "Hunting": 80.0, "Storage": 60.0, "Education": 160.0,
    "Toolmaking": 50.0, "Shelter Building": 50.0, "Fishing": 60.0, "Woodcutting": 60.0,
    "Planting": 60.0, "Preservation": 120.0, "Forestry": 80.0, "Crop Rotation": 160.0,
    "Stoneworking": 80.0, "Carpentry": 120.0, "Masonry": 160.0, "Sanitation": 160.0, "Waterworks": 200.0
}
const JOB_TECH = {"Gathering": "", "Fishing": "Fishing", "Logging": "Woodcutting", "Quarrying": "Stoneworking", "Construction": "Shelter Building", "Farming": "Planting"}
const PREREQUISITES = {
    "Joinery": ["Carpentry"],
    "Pottery": ["Storage", "Stoneworking"], "Boatbuilding": ["Carpentry", "Fishing"],
    "River Navigation": ["Boatbuilding"], "Archery": ["Hunting", "Carpentry"],
    "Military Organization": ["Community Organization", "Toolmaking"], "Writing": ["Education", "Community Organization"],
    "Community Organization": ["Shelter Building"],
    "Scouting": [],
    "Basketry": [], "Hunting": ["Toolmaking"], "Storage": ["Shelter Building"], "Education": ["Carpentry"],
    "Toolmaking": [], "Shelter Building": ["Toolmaking"], "Fishing": ["Toolmaking"], "Woodcutting": ["Toolmaking"],
    "Planting": [], "Stoneworking": ["Toolmaking"], "Preservation": ["Planting"],
    "Forestry": ["Planting", "Woodcutting"], "Crop Rotation": ["Preservation"],
    "Carpentry": ["Stoneworking", "Woodcutting", "Shelter Building"], "Masonry": ["Carpentry"],
    "Sanitation": ["Stoneworking"], "Waterworks": ["Planting", "Sanitation"]
}
const TECH_DETAILS = {
    "Joinery": "Unlocks carpenter workshops. The first completed workshop speeds construction up to 25%, spending 0.2 wood per extra unit of construction work. Additional workshops do not stack.",
    "Pottery": "Unlocks pottery workshops. The first completed workshop adds 100 shared storage and halves remaining food spoilage; additional workshops add storage only.",
    "Boatbuilding": "Unlocks boatyards. Each completed boatyard supplies one reusable scouting boat; river expeditions reserve a boat until return. Boat expeditions reach 60 map units from camp.",
    "River Navigation": "Boat expeditions travel 50% faster and reach the full world-view bounds. Requires a completed boatyard. Land travel and survey time are unchanged.",
    "Archery": "Unlocks archer training at Training Grounds. Existing trained archers are retained.",
    "Military Organization": "Unlocks barracks and speeds soldier training by 25%. Existing barracks and troops are retained.",
    "Writing": "Unlocks archives. Each completed archive adds 50% of base daily research output alongside School bonuses.",
    "Community Organization": "Unlocks one Town Hall: more buildable land, policies and standing orders.",
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
    "Waterworks": "Develop irrigation from wells. Fields grow another 25% faster and Bathhouses become available. Requires a completed well."
}
var day: float = 0
var population: int = 30
var resources: Dictionary = {"food": 30.0, "wood": 40.0, "stone": 20.0}
var assignments: Dictionary = {"Gathering": 30, "Fishing": 0, "Logging": 0, "Quarrying": 0, "Construction": 0, "Farming": 0}
var buildings: Array = []
var armies: Array = []
var owned_commanders: Array = []
var next_army_id := 1
var defense_order := "Hold settlement"
var emergency_defenders: Array = []
var battle_reports: Array = []
var technologies: Array = ["Scouting"]
var research: String = "Toolmaking"
var queued_research: String = ""
var research_progress: float = 0
var research_saved: Dictionary = {}
var research_points_version: int = 4
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
var government: Dictionary = {"influence": 0.0, "births": "Allowed", "active": {}, "feast_until": 0.0, "food_start": 30.0, "food_stop": 45.0, "food_groups": ["Idle", "Quarrying", "Construction"], "food_active": false}
const CIVIC_POLICIES = {
    "Community Feast": {"cost": 3.0, "upkeep": 0.0, "detail": "Spend 10 food for +8 happiness for 15 days. Cannot stack."},
    "Extended Workdays": {"cost": 2.0, "upkeep": 0.03, "detail": "+15% civilian work, -8 happiness. Excludes Rest Days."},
    "Rest Days": {"cost": 2.0, "upkeep": 0.0, "detail": "+6 happiness, -10% civilian work. Excludes Extended Workdays."},
    "Winter Preparedness": {"cost": 2.0, "upkeep": 0.0, "detail": "Autumn/winter food response starts at least at 60 days, recovers to 75; houses and wells take construction priority."},
    "Education Priority": {"cost": 3.0, "upkeep": 0.02, "detail": "Requires a completed School. +50% apprenticeship/schooling progress; learners work at 50% rather than 75%."},
    "Conservation": {"cost": 2.0, "upkeep": 0.0, "detail": "Gathering and logging output -15%; wildlife and woodland recovery +50%."}
}
var migration_clock := 0.0
var birth_progress := 0.0
var happiness := 50.0
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

func discovered_resource_capacity(resource: String) -> float:
    # Match resource_deposits.gd's deterministic near-to-far reserve partition.
    # This prevents workers from consuming the reserve represented by unseen objects.
    var nodes: Array = []
    if resource == "wood":
        var forest_rng := RandomNumberGenerator.new()
        forest_rng.seed = 72419
        for i in range(1200):
            var x := forest_rng.randf_range(-170, 95)
            var z := forest_rng.randf_range(-125, 125)
            var tree_size := forest_rng.randf_range(0.65, 1.5)
            if absf(x) > 92 or absf(z) > 92: continue
            if Vector2(x + 4, z).length() < 13.5: continue
            if Vector2(x + 4, z).length() < 13.5 or absf(x - (10 + sin(z * 0.095) * 3)) < 4.6: continue
            nodes.append({"point": Vector2(x, z), "weight": tree_size * tree_size * tree_size})
        for tree in [[-13.5, -5.5, 0.95], [3.9, -4.0, 0.75], [-14.5, 7.0, 0.8]]:
            nodes.append({"point": Vector2(tree[0], tree[1]), "weight": pow(float(tree[2]), 3.0)})
    elif resource == "stone":
        var rock_rng := RandomNumberGenerator.new()
        rock_rng.seed = 72419
        for i in range(38):
            var x := rock_rng.randf_range(-24, -15)
            var z := rock_rng.randf_range(-18, -7)
            var sx := rock_rng.randf_range(0.35, 1.0)
            var sy := rock_rng.randf_range(0.4, 1.4)
            var sz := rock_rng.randf_range(0.4, 1.0)
            rock_rng.randf() # rotation.x
            rock_rng.randf() # rotation.y
            rock_rng.randf() # rotation.z
            nodes.append({"point": Vector2(x, z), "weight": sx * sy * sz})
        for i in range(24):
            var z := rock_rng.randf_range(-25, 25)
            var x := 10 + sin(z * 0.095) * 3 + (3.2 if i % 2 == 0 else -3.2)
            nodes.append({"point": Vector2(x, z), "weight": 0.35 * 0.22 * 0.3})
    else:
        return 0.0
    nodes.sort_custom(func(a, b):
        var pa: Vector2 = a.point
        var pb: Vector2 = b.point
        var da := pa.distance_squared_to(Vector2(-4, 0))
        var db := pb.distance_squared_to(Vector2(-4, 0))
        if not is_equal_approx(da, db): return da < db
        if not is_equal_approx(pa.x, pb.x): return pa.x < pb.x
        return pa.y < pb.y)
    var total_weight := 0.0
    for node in nodes: total_weight += float(node.weight)
    var reserve_total := 1200.0 if resource == "wood" else 1500.0
    var capacity := 0.0
    for node in nodes:
        var point: Vector2 = node.point
        if explored.has(cell_key(point)):
            capacity += reserve_total * float(node.weight) / maxf(total_weight, 0.001)
    return capacity

func discovered_resource_remaining(resource: String, reserve: float) -> float:
    # Depletion follows the same near-to-far ordering as the rendered deposits.
    # Sum only the remaining portions belonging to cells the player has discovered.
    var discovered_capacity := discovered_resource_capacity(resource)
    var reserve_total := 1200.0 if resource == "wood" else 1500.0
    var harvested := maxf(0.0, reserve_total - reserve)
    return maxf(0.0, discovered_capacity - harvested)

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
    var count := 0
    var unavailable: Array = scouting_units() + military_ids()
    for person in people:
        if person.age >= 16 and person.age < 65 and not on_birth_leave(person) and int(person.id) not in unavailable: count += 1
    return count

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
    return ((outbound + returning) / mission_travel_rate(mission) + survey) / travel_factor()

func research_points_per_day() -> float:
    return BASE_RESEARCH_POINTS_PER_DAY * (1.0 + completed("School") * 0.25 + completed("Archive") * 0.5)

func food_spoilage_rate() -> float:
    return (0.0004 if "Preservation" in technologies else 0.002) * (0.5 if completed("Pottery Workshop") > 0 else 1.0)

func point_on_river(local_point: Vector2) -> bool:
    var point := local_point + Vector2(float(world_origin[0]), float(world_origin[1]))
    var segment := floorf(point.y)
    var center := lerpf(10.0 + sin(segment * 0.095) * 3.0, 10.0 + sin((segment + 1.0) * 0.095) * 3.0, point.y - segment)
    return absf(point.x - center) <= 2.45

func scout_needs_boat(destination: Vector2) -> bool:
    # Check the entire straight route against the rendered curved water edge.
    var origin := Vector2(-4, 0)
    var steps := maxi(1, ceili(origin.distance_to(destination) * 2.0))
    for i in range(steps + 1):
        var point := origin.lerp(destination, float(i) / steps) + Vector2(float(world_origin[0]), float(world_origin[1]))
        var segment := floorf(point.y)
        var edge := lerpf(10.0 + sin(segment * 0.095) * 3.0, 10.0 + sin((segment + 1.0) * 0.095) * 3.0, point.y - segment) - 2.45
        if point.x >= edge: return true
    return false

func available_scout_boats() -> int:
    var used := 0
    var missions: Array = scout_missions if not scout_missions.is_empty() else ([scout_mission] if not scout_mission.is_empty() else [])
    for mission in missions:
        if bool(mission.get("boat", false)): used += 1
    return maxi(0, completed("Boatyard") - used)

func mission_travel_rate(mission: Dictionary) -> float:
    return float(mission.get("travel_rate", SCOUT_TRAVEL_RATE))

func scouting_block(destination: Vector2) -> String:
    if "Scouting" not in technologies: return "Research Scouting first."
    if destination.distance_to(Vector2(-4, 0)) <= CAMP_RADIUS: return "Choose a destination outside the civilization's camp area."
    if absf(destination.x) > 88 or absf(destination.y) > 88: return "Destination lies beyond this world view."
    if scout_needs_boat(destination):
        if "Boatbuilding" not in technologies: return "Research Boatbuilding and complete a boatyard to cross the river."
        if available_scout_boats() <= 0: return "No boat available. Complete a boatyard or wait for a boat expedition to return."
        if "River Navigation" not in technologies and destination.distance_to(Vector2(-4, 0)) > 60.0: return "Boat expeditions beyond 60 map units require River Navigation."
    var cost := scout_food_cost(destination)
    if resources.food < cost: return "This trip needs %d food for its distance and duration." % cost
    if adults() < 3: return "Three working-age settlers are needed."
    var units: Array = []
    for person in people:
        if person.age >= 16 and person.age < 65 and not on_birth_leave(person) and not is_pregnant(person) and person.training.is_empty() and int(person.id) not in military_ids() and int(person.id) not in scouting_units():
            units.append(int(person.id))
            if units.size() == 3: break
    if units.size() < 3: return "Three adults outside training are needed."
    return ""

func send_scouts(destination: Vector2) -> String:
    var blocked := scouting_block(destination)
    if not blocked.is_empty(): return blocked
    var units: Array = []
    for person in people:
        if person.age >= 16 and person.age < 65 and not on_birth_leave(person) and not is_pregnant(person) and person.training.is_empty() and int(person.id) not in military_ids() and int(person.id) not in scouting_units():
            units.append(int(person.id))
            if units.size() == 3: break
    var cost := scout_food_cost(destination)
    resources.food -= cost
    var origin := Vector2(-4, 0) + (destination - Vector2(-4, 0)).normalized() * CAMP_RADIUS
    var mission := {"units": units, "origin": [origin.x, origin.y], "destination": [destination.x, destination.y], "started": day, "progress": 0.0, "travel": maxf(0.001, destination.distance_to(origin) / 2), "food": cost, "survey_days": -1.0, "surveyed": false, "boat": scout_needs_boat(destination), "travel_rate": SCOUT_TRAVEL_RATE * (1.5 if scout_needs_boat(destination) and "River Navigation" in technologies else 1.0)}
    scout_missions.append(mission)
    scout_mission = scout_missions[0]
    clamp_assignments()
    announce("Three settlers departed on a scouting expedition with %d food." % cost)
    return "Scouts dispatched with %d food. Their return takes approximately %.0f game days." % [cost, scout_remaining_days()]

func scout_food_cost(destination: Vector2) -> int:
    var origin := Vector2(-4, 0) + (destination - Vector2(-4, 0)).normalized() * CAMP_RADIUS
    var outbound := maxf(0.001, destination.distance_to(origin) / 2.0)
    var returning := outbound
    # Three adults consume one food per 30 days at normal rations; pack their round-trip needs.
    var rate := SCOUT_TRAVEL_RATE * (1.5 if scout_needs_boat(destination) and "River Navigation" in technologies else 1.0)
    var expected_days := ((outbound + returning) / rate + 3.0) / travel_factor()
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
            var outbound_time := minf(mission_remaining, (travel - progress) / mission_travel_rate(mission))
            progress += outbound_time * mission_travel_rate(mission)
            mission_remaining -= outbound_time
        if progress >= travel and survey_days < 0.0:
            survey_days = 3.0 if has_civilization_near(Vector2(mission.destination[0], mission.destination[1])) else 0.0
            mission.survey_days = survey_days
        if progress >= travel and progress < travel + survey_days:
            var survey_time := minf(mission_remaining, travel + survey_days - progress)
            progress += survey_time
            mission_remaining -= survey_time
        if progress >= travel + survey_days:
            progress = minf(travel + survey_days + returning_travel, progress + mission_remaining * mission_travel_rate(mission))
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

func elders() -> int:
    var count := 0
    for person in people:
        if person.age >= ELDER_DEATH_AGE_MIN: count += 1
    return count

func food_need() -> float:
    var deployed := 0
    for army in armies:
        if army.status in ["Marching", "Fighting", "Returning", "Holding", "Raiding"]: deployed += army.soldiers.size()
    return maxf(0, population - children() * 0.5 - deployed - scouting_units().size()) / 90.0 * ration_level

func happiness_influences() -> Array:
    var factors: Array = [{"name": "Community spirit", "value": 50.0, "detail": "The starting baseline for this settlement."}]
    var reserve_days := float(resources.food) / maxf(0.001, (population - children() * 0.5) / 90.0)
    var food_value := 10.0 if reserve_days >= 90 else 0.0 if reserve_days >= 45 else -10.0 if reserve_days >= 27 else -20.0 if resources.food > 0 else -40.0
    factors.append({"name": "Food reserves", "value": food_value, "detail": "%.0f days at normal rations. Build reserves and reliable production." % reserve_days})
    factors.append({"name": "Ration policy", "value": -15.0 if ration_level < 1 else 5.0 if ration_level > 1 else 0.0, "detail": "Reduced rations save food but strain people; generous rations use more food."})
    factors.append({"name": "Water quality", "value": -5.0 if completed("Well") == 0 else 0.0, "detail": "Untreated water. Research Sanitation and build a well." if completed("Well") == 0 else "A completed well supplies treated water."})
    factors.append({"name": "Crowding", "value": -minf(25.0, maxf(0, population - housing()) * 4.0), "detail": "%d people / %d shelter places." % [population, housing()]})
    var beds := completed("House") * (15 if "Masonry" in technologies else 10) + military_housed()
    var missing_beds := maxi(0, population - beds)
    factors.append({"name": "Bedding & comfort", "value": -5.0 * missing_beds / maxf(1, population), "detail": "%d settlers lack permanent beds. Houses and occupied barracks include bedding; starting tents do not." % missing_beds})
    var winter: bool = int(day / 90) % 4 == 3
    factors.append({"name": "Living conditions", "value": -8.0 * missing_beds / maxf(1, population) if winter else 0.0, "detail": "Winter exposes temporary shelters to cold." if winter else "No seasonal shelter penalty."})
    factors.append({"name": "Prolonged hardship", "value": -minf(15.0, starvation * 0.5), "detail": "Starvation leaves lasting strain; recovering food gradually relieves it."})
    factors.append({"name": "Education", "value": 5.0 if completed("School") > 0 else 0.0, "detail": "A school supports the community and prepares the next generation."})
    factors.append({"name": "Public bathing", "value": 6.0 if completed("Bathhouse") > 0 and completed("Well") > 0 else 0.0, "detail": "A supplied bathhouse adds 6 happiness; additional bathhouses do not stack." if completed("Bathhouse") > 0 and completed("Well") > 0 else "Requires a completed Bathhouse and Well."})
    var policy_happiness := (8.0 if float(government.feast_until) > day else 0.0) + (-8.0 if civic_active("Extended Workdays") else 0.0) + (6.0 if civic_active("Rest Days") else 0.0)
    policy_happiness += 3.0 if government.births == "Encouraged" else -12.0 if government.births == "Forbidden" else 0.0
    factors.append({"name": "Town Hall policies", "value": policy_happiness, "detail": "Feasts, working time and birth policy affect community happiness."})
    factors.append({"name": "Daily mood", "value": 2.0 * sin(day / 7.0), "detail": "Slow natural mood variation, up to two points."})
    return factors

func refresh_happiness(dt: float = 0.0) -> void:
    var target := 0.0
    for factor in happiness_influences(): target += float(factor.value)
    if dt > 0: happiness = clampf(lerpf(happiness, target, 1.0 - exp(-dt / 3.0)), 0, 100)

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
    var required: String = {"Field": "Planting", "Well": "Sanitation", "School": "Education", "Storehouse": "Storage", "Training Grounds": "Toolmaking", "Barracks": "Military Organization", "Palisade": "Carpentry", "Wall": "Masonry", "Town Hall": "Community Organization", "Pottery Workshop": "Pottery", "Boatyard": "Boatbuilding", "Archive": "Writing", "Carpenter Workshop": "Joinery", "Bathhouse": "Waterworks"}.get(kind, "")
    if not required.is_empty() and required not in technologies: return "Requires " + required + "."
    if kind == "Bathhouse" and completed("Well") == 0: return "Requires a completed Well."
    if kind == "Town Hall":
        for building in buildings:
            if building.kind == "Town Hall": return "Only one Town Hall per settlement."
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
        if person.age >= 16 and person.age < 65 and not on_birth_leave(person) and int(person.id) not in scouting_units() and int(person.id) not in military_ids(): available.append(person)
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
        amount += (1.0 + float(person.skill) if person.profession == job else 1.0) * ((0.5 if civic_active("Education Priority") else 0.75) if not person.training.is_empty() else 1.0)
    amount *= 1.0 + (happiness - 50.0) * 0.005
    if civic_active("Extended Workdays"): amount *= 1.15
    if civic_active("Rest Days"): amount *= 0.9
    if civic_active("Conservation") and job in ["Gathering", "Logging"]: amount *= 0.85
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
        if person.age >= 16 and person.age < 65 and not on_birth_leave(person) and not is_pregnant(person) and person.training.is_empty() and person.profession != job and int(person.id) not in scouting_units() and int(person.id) not in military_ids():
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
        if not person.training.is_empty() and not on_birth_leave(person):
            person.training_progress += dt * (1.5 if completed("School") > 0 else 1.0) * (1.5 if civic_active("Education Priority") else 1.0)
            if person.training_progress >= 60:
                person.profession = person.training
                person.skill = 0.30
                person.training = ""
                person.training_progress = 0.0
                announce("Settler %d qualified in %s." % [person.id, person.profession.to_lower()])
        if person.age >= 12 and person.age < 16 and completed("School") > 0 and person.career != "General" and not person.career.is_empty() and job_unlocked(person.career):
            person.profession = person.career
            person.skill = minf(0.30, float(person.skill) + dt / 1800.0 * (1.5 if civic_active("Education Priority") else 1.0))
        if was_child and person.age >= 16:
            announce("A young settler joined the adult workforce.")
    for job in job_roster:
        for person in job_roster[job]:
            if person.profession == job: person.skill = minf(0.60, float(person.skill) + dt * 0.0003)
    advance_pregnancies(dt)
    population = people.size()
    refresh_happiness(dt)
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
    if allow_births and government.births != "Forbidden" and happiness >= 50 and housing() > people.size() and resources.food >= population * 0.5:
        birth_progress += adults() * 0.035 / 360.0 * dt * (1.5 if government.births == "Encouraged" else 1.0)
        if birth_progress >= 1:
            var candidates: Array = []
            for person in people:
                if person.age >= 18 and person.age < 45 and not is_pregnant(person) and not on_birth_leave(person) and int(person.id) not in military_ids() and int(person.id) not in scouting_units() and person.training.is_empty(): candidates.append(person)
            if not candidates.is_empty():
                # Rotate opportunities through adults instead of repeatedly choosing the first person.
                candidates.sort_custom(func(a, b): return float(a.get("last_birth_day", -10000.0)) < float(b.get("last_birth_day", -10000.0)))
                candidates[0]["pregnancy_due"] = day + PREGNANCY_DAYS
                birth_progress -= 1.0
                announce("A settler is expecting a child. Leave begins during the final 90 days.")
            else: birth_progress = minf(birth_progress, 1.0)
    population = people.size()
    advance_armies(0)
    if automatic_workforce: apply_targets()
    else: clamp_assignments()
    prepare_roster(effective_assignments())

func capacity() -> float:
    return (180.0 if camp_object_present("cache") else 0.0) + completed("Storehouse") * 200.0 + completed("Pottery Workshop") * 100.0

func housing() -> int:
    return (15 if camp_object_present("tent_east") else 0) + (15 if camp_object_present("tent_west") else 0) + completed("House") * (15 if "Masonry" in technologies else 10) + military_housed()

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
    if emergency_food and job in government.food_groups and assigned > int(assignments[job]):
        emergency_food = false
        announce("Manual workforce order: food-shortage diversion disabled.")
    assignments[job] = assigned
    prepare_roster(effective_assignments())

func announce(message: String) -> void:
    events.push_front(message)
    if events.size() > 24: events.resize(24)

func camp_object_present(id: String) -> bool:
    return STARTING_OBJECTS.has(id) and float(camp_dismantling.get(id, 0.0)) < 1.0

func order_dismantle(id: String) -> String:
    if not STARTING_OBJECTS.has(id): return "Unknown starting object."
    if not job_unlocked("Construction"): return "Requires Shelter Building."
    if not camp_object_present(id): return "Already dismantled."
    if camp_dismantling.has(id): return "Already queued for dismantling."
    camp_dismantling[id] = 0.0
    announce("%s queued for dismantling. Assign construction workers." % STARTING_OBJECTS[id].kind)
    return "Dismantling queued. Assign construction workers and let time advance."

func order_build(kind: String, q: int, r: int) -> String:
    if not BUILDINGS.has(kind): return "Unknown building."
    var center := Vector2(3.0 * q, sqrt(3.0) * 2.0 * (r + q * 0.5))
    if center.distance_to(Vector2(-4, 0)) > build_radius() or center.x > (8 if completed("Town Hall") > 0 else 4): return "Choose land inside your buildable clearing."
    for id in STARTING_OBJECTS:
        var item: Dictionary = STARTING_OBJECTS[id]
        if camp_object_present(id) and center.distance_to(Vector2(item.point[0], item.point[1])) < float(item.radius) + 2.0:
            return "A %s occupies this site. Dismantle it first." % item.kind
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
    var facility: String = {"Crop Rotation": "Field", "Masonry": "Storehouse", "Waterworks": "Well", "River Navigation": "Boatyard"}.get(tech, "")
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
    var reserve := float(resources.food) / maxf(food_need(), 0.001)
    var winter_order := civic_active("Winter Preparedness") and int(day / 90) % 4 in [2, 3]
    var start := maxf(float(government.food_start), 60.0 if winter_order else 0.0)
    var stop := maxf(float(government.food_stop), 75.0 if winter_order else 0.0)
    if not emergency_food: government.food_active = false
    elif reserve < start: government.food_active = true
    elif reserve >= stop: government.food_active = false
    if bool(government.food_active) and wildlife > 0:
        var season := int(day / 90) % 4
        var efficiency: float = (1.0 + (happiness - 50) * 0.005) * (1.15 if civic_active("Extended Workdays") else 1.0) * (0.9 if civic_active("Rest Days") else 1.0)
        var gather_rate: float = 0.11 * [1.05, 1.15, 1.0, 0.5][season] * efficiency * (1.2 if "Basketry" in technologies else 1.0) * (1.25 if "Hunting" in technologies else 1.0) * (0.85 if civic_active("Conservation") else 1.0)
        var fish_rate: float = 0.14 * [1.0, 1.15, 0.9, 0.55][season] * efficiency
        var spoilage_rate: float = food_spoilage_rate() * [1.0, 1.35, 0.9, 0.55][season]
        # Cover consumption/spoilage and rebuild reserves over roughly 30 days.
        var needed := maxi(0, ceili((food_need() + float(resources.food) * spoilage_rate + maxf(0, stop * food_need() - float(resources.food)) / 30.0 - int(work.Fishing) * fish_rate) / maxf(gather_rate, 0.001)) - int(work.Gathering))
        var idle := workforce_capacity()
        for job in JOBS: idle -= int(work[job])
        for group in government.food_groups:
            var available := maxi(0, idle) if group == "Idle" else int(work[group])
            var diverted := mini(needed, available)
            work.Gathering += diverted
            if group != "Idle": work[group] -= diverted
            needed -= diverted
            if needed <= 0: break
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
    advance_government(dt)
    advance_armies(dt)
    update_exploration(dt)
    if automatic_workforce: apply_targets()
    clamp_assignments()
    var work := effective_assignments()
    prepare_roster(work)
    # Rates include travel and rest; nobody contributes a full day of labor.
    var season := int(day / 90.0) % 4
    var gathered := minf(wildlife, labor("Gathering") * dt * (0.11 * [1.05, 1.15, 1.0, 0.5][season]) * (1.2 if "Basketry" in technologies else 1.0) * (1.25 if "Hunting" in technologies else 1.0))
    wildlife = minf(300, wildlife - gathered + [0.30, 0.24, 0.18, 0.08][season] * dt * (1.5 if civic_active("Conservation") else 1.0))
    var food_produced: float = gathered + labor("Fishing") * dt * (0.14 * [1.0, 1.15, 0.9, 0.55][season])
    resources.food += food_produced
    var wood_unharvested := discovered_resource_remaining("wood", forest)
    var timber := minf(wood_unharvested, labor("Logging") * dt * 0.12 * (0.8 if season == 3 else 1.0))
    forest -= timber
    if "Forestry" in technologies: forest = minf(1200, forest + labor("Logging") * dt * 0.04 * (1.5 if civic_active("Conservation") else 1.0) * (0.0 if season == 3 else 1.25 if season == 0 else 1.0))
    resources.wood += timber
    var stone_unharvested := discovered_resource_remaining("stone", quarry)
    var stone := minf(stone_unharvested, labor("Quarrying") * dt * 0.09 * (0.75 if season == 3 else 1.0) * (1.25 if "Stoneworking" in technologies else 1.0))
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
    var builder_labor := labor("Construction")
    var construction_rate := 0.35 * (0.75 if season == 3 else 1.0) * (1.25 if "Carpentry" in technologies else 1.0)
    # Dismantling takes priority, sharing the same labor pool with construction.
    for id in camp_dismantling:
        if float(camp_dismantling[id]) >= 1.0 or builder_labor <= 0: continue
        var item: Dictionary = STARTING_OBJECTS[id]
        var assigned: float = minf(builder_labor, 3.0)
        camp_dismantling[id] = minf(1.0, float(camp_dismantling[id]) + assigned * dt * construction_rate / float(item.work))
        builder_labor -= assigned
        if float(camp_dismantling[id]) >= 1.0:
            resources.wood += float(item.wood)
            resources.stone += float(item.stone)
            revision += 1
            announce("%s dismantled; recovered %.0f wood and %.0f stone. Its space is now clear." % [item.kind, item.wood, item.stone])
    var build_queue: Array = buildings.duplicate()
    if civic_active("Winter Preparedness") and season in [2, 3]:
        build_queue.sort_custom(func(a, b): return int(a.kind in ["House", "Well"]) > int(b.kind in ["House", "Well"]))
    for b in build_queue:
        if b.progress < 1 and builder_labor > 0:
            var assigned_labor: float = minf(builder_labor, float(BUILDING_WORKER_CAPS.get(b.kind, 4.0)))
            var budget := assigned_labor * dt * construction_rate
            var needed: float = (1 - b.progress) * BUILDINGS[b.kind].work
            # Pay only for workshop-assisted work actually used at this site.
            # Limit the boost to available timber, then continue at normal speed.
            var extra_work := minf(budget * 0.25, float(resources.wood) / 0.2) if completed("Carpenter Workshop") > 0 else 0.0
            var used := minf(budget + extra_work, needed)
            if extra_work > 0.0:
                resources.wood = maxf(0.0, float(resources.wood) - used * extra_work / (budget + extra_work) * 0.2)
            b.progress = minf(1, b.progress + used / BUILDINGS[b.kind].work)
            builder_labor -= assigned_labor
            if b.progress >= 1:
                revision += 1
                announce("%s completed." % b.kind)
    if not research.is_empty() and research_block(research).is_empty():
        research_progress += dt * research_points_per_day()
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
    resources.food *= pow(1.0 - food_spoilage_rate(), dt * [1.0, 1.35, 0.9, 0.55][season])
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
    return {"happiness": happiness, "government": government, "camp_dismantling": camp_dismantling, "version": 1, "research_points_version": research_points_version, "map_format": map_format, "has_seen_intro": has_seen_intro, "world_origin": world_origin, "shared_region": shared_region, "known_civilizations": known_civilizations, "known_armies": known_armies, "army_sights": army_sights, "armies": armies, "owned_commanders": owned_commanders, "next_army_id": next_army_id, "defense_order": defense_order, "emergency_defenders": emergency_defenders, "battle_reports": battle_reports, "ration_level": ration_level, "explored": explored, "scout_mission": scout_mission, "scout_missions": scout_missions, "discoveries": discoveries, "people": people, "next_person_id": next_person_id, "workforce_targets": workforce_targets, "generation_targets": generation_targets, "automatic_workforce": automatic_workforce, "allow_migration": allow_migration, "allow_births": allow_births, "migration_clock": migration_clock, "birth_progress": birth_progress, "day": day, "population": population, "resources": resources, "material_production": material_production, "assignments": assignments, "buildings": buildings, "technologies": technologies, "research": research, "queued_research": queued_research, "research_progress": research_progress, "research_saved": research_saved, "forest": forest, "quarry": quarry, "wildlife": wildlife, "starvation": starvation, "events": events, "emergency_food": emergency_food, "days_per_real_day": days_per_real_day, "saved_at": Time.get_unix_time_from_system()}

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
    camp_dismantling = data.get("camp_dismantling", {}).duplicate(true)
    migrate_government(data)
    migrate_research_points(data)
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
        if key not in ["version", "saved_at"] and key in snapshot(): set(key, data[key])
    migrate_government(data)
    migrate_research_points(data)
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

func migrate_research_points(data: Dictionary) -> void:
    # Preserve completion percentage as the point-cost scale changes.
    var saved_version := int(data.get("research_points_version", 1))
    var progress_scale := 100.0 if saved_version < 2 else 50.0 if saved_version < 3 else 10.0 if saved_version < 4 else 1.0
    if progress_scale != 1.0:
        research_progress *= progress_scale
        for tech in research_saved:
            research_saved[tech] = float(research_saved[tech]) * progress_scale
    research_points_version = 4

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
    for army in armies:
        if army.commander != "None" and army.commander in Warfare.COMMANDERS and army.commander not in owned_commanders: owned_commanders.append(army.commander)
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
            army.training += days * training_rate * (1.25 if "Military Organization" in technologies else 1.0)
            if army.training >= Warfare.UNITS[army.unit].days:
                army.status = "Ready"
                announce("%d %s completed training%s." % [army.soldiers.size(), army.unit.to_lower(), " and are available to form armies" if army.get("reserve", false) else ""])
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


func build_radius() -> float:
    return CAMP_RADIUS + (4.0 if completed("Town Hall") > 0 else 0.0)

func civic_active(name: String) -> bool:
    return completed("Town Hall") > 0 and bool(government.active.get(name, false)) and (name != "Education Priority" or completed("School") > 0)

func enact_civic(name: String, value: Variant) -> String:
    if completed("Town Hall") == 0: return "Complete a Town Hall first."
    if name == "Food response":
        if not value is Dictionary: return "Invalid food response."
        if not value.get("start") is float and not value.get("start") is int: return "Invalid threshold."
        if not value.get("stop") is float and not value.get("stop") is int: return "Invalid threshold."
        if not value.get("groups") is Array: return "Invalid worker priority."
        var start := float(value.get("start", -1))
        var stop := float(value.get("stop", -1))
        var groups: Array = value.get("groups", [])
        if not is_finite(start) or not is_finite(stop) or start < 1 or stop <= start or stop > 360: return "Use thresholds from 1 to 360 days; recovery must exceed activation."
        var seen: Array = []
        for group in groups:
            if group not in ["Idle", "Quarrying", "Construction", "Logging"] or group in seen: return "Invalid worker priority."
            seen.append(group)
        government.food_start = start
        government.food_stop = stop
        government.food_groups = groups.duplicate()
        return "Food response saved."
    var cost := 0.0
    if name == "Births":
        if value not in ["Encouraged", "Allowed", "Forbidden"]: return "Invalid birth policy."
        if government.births == value: return "Already selected."
        cost = {"Encouraged": 2.0, "Allowed": 1.0, "Forbidden": 3.0}[value]
    elif CIVIC_POLICIES.has(name):
        if not value is bool: return "Invalid policy choice."
        if name == "Education Priority" and completed("School") == 0: return "Complete a School first."
        if name == "Community Feast":
            if float(government.feast_until) > day: return "A feast is already in effect."
            if resources.food < 10: return "A feast requires 10 food."
        elif bool(government.active.get(name, false)) == value: return "Already selected."
        cost = float(CIVIC_POLICIES[name].cost) if value else 0.0
    else: return "Unknown policy."
    if float(government.influence) < cost: return "Not enough influence."
    government.influence = float(government.influence) - cost
    if name == "Births":
        government.births = value
        allow_births = value != "Forbidden"
    elif name == "Community Feast":
        resources.food -= 10
        government.feast_until = day + 15
    else:
        government.active[name] = value
        if value and name == "Extended Workdays": government.active["Rest Days"] = false
        if value and name == "Rest Days": government.active["Extended Workdays"] = false
    announce("Town Hall: %s changed." % name)
    return "Policy enacted. Happiness will adjust gradually."

func advance_government(dt: float) -> void:
    if completed("Town Hall") == 0: return
    government.influence = minf(10.0, float(government.influence) + dt * (0.05 + 0.001 * happiness))
    for name in CIVIC_POLICIES:
        if not civic_active(name): continue
        var upkeep := float(CIVIC_POLICIES[name].upkeep) * dt
        if float(government.influence) + 0.000001 < upkeep:
            government.active[name] = false
            announce("%s suspended: insufficient influence. Re-enact it at the Town Hall." % name)
        else: government.influence = maxf(0.0, float(government.influence) - upkeep)

func migrate_government(data: Dictionary) -> void:
    var defaults: Dictionary = {"influence": 0.0, "births": "Allowed" if allow_births else "Forbidden", "active": {}, "feast_until": 0.0, "food_start": 30.0, "food_stop": 45.0, "food_groups": ["Idle", "Quarrying", "Construction"], "food_active": false}
    var saved: Dictionary = data.get("government", {})
    for key in defaults:
        if saved.has(key): defaults[key] = saved[key]
    government = defaults


func is_pregnant(person: Dictionary) -> bool:
    return float(person.get("pregnancy_due", -1.0)) >= 0.0

func on_birth_leave(person: Dictionary) -> bool:
    var due := float(person.get("pregnancy_due", -1.0))
    return (due >= 0.0 and day >= due - LATE_PREGNANCY_DAYS) or float(person.get("birth_recovery_until", -1.0)) > day

func birth_leave_count() -> int:
    var count := 0
    for person in people:
        if person.age >= 16 and person.age < 65 and on_birth_leave(person): count += 1
    return count

func advance_pregnancies(dt: float) -> void:
    if dt <= 0: return
    for person in people.duplicate():
        var due := float(person.get("pregnancy_due", -1.0))
        if due < 0.0 or day < due: continue
        person.erase("pregnancy_due")
        person["last_birth_day"] = due
        person["birth_recovery_until"] = due + BIRTH_RECOVERY_DAYS
        var newborn := {"id": next_person_id, "age": maxf(0.0, day - due) / 360.0, "profession": "General", "skill": 0.0, "training": "", "training_progress": 0.0, "career": next_career(), "parent_id": int(person.id)}
        newborn["death_age"] = lifespan_for(next_person_id)
        people.append(newborn)
        next_person_id += 1
        announce("A child was born. Settler %d is recovering for 60 days." % int(person.id))
