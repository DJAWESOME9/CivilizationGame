extends Node3D

const Logistics = preload("res://scripts/outposts.gd")
var world: Node3D
var rows: Array = []
var geometry := Node3D.new()
var signature := ""
var timer := 0.0

func setup(scene: Node3D, page: VBoxContainer) -> void:
    world = scene
    add_child(geometry)
    page.add_child(world.label("Outposts & supply routes", 18, Color("eee1bf")))
    var help: Label = world.label("Scout a site and its land route. Founding: 3 settlers + 1 carrier, 20 wood, 5 stone, 16 food. Road crews stop extraction while building.", 13, Color("c8d1bc"))
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(help)
    for i in range(Logistics.SITES.size()):
        var site_id: int = i
        var title: Label = world.label(Logistics.SITES[i].name, 15, Color("eee1bf"))
        page.add_child(title)
        var info: Label = world.label("", 12, Color("c8d1bc"))
        info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        page.add_child(info)
        var locate: Button = world.game_button(page, "Locate site / scout route", func():
            world.selected_land = Logistics.SITES[site_id].point
            world.has_selected_land = true
            world.exploration.select_land(world.selected_land)
            world.focus.x = world.selected_land.x
            world.focus.z = world.selected_land.y
            world.update_camera()
            world.refresh_game())
        var found: Button = world.game_button(page, "Found outpost", func(): issue("found_outpost", site_id))
        var road: Button = world.game_button(page, "Build road", func(): issue("outpost_road", site_id))
        var route: Button = world.game_button(page, "Pause supply route", func(): issue("outpost_route", site_id))
        var recall: Button = world.game_button(page, "Recall crew", func(): issue("recall_outpost", site_id))
        for button in [locate, found, road, route, recall]:
            button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        rows.append({"title": title, "info": info, "locate": locate, "found": found, "road": road, "route": route, "recall": recall})
    refresh()

func issue(action: String, site: int) -> void:
    world.feedback.text = world.order(action, [site])
    world.sim.save_game()
    if is_instance_valid(world.citizens): world.citizens.sync_people()
    world.refresh_game()
    refresh()

func _process(delta: float) -> void:
    timer += delta
    if timer < 0.3: return
    timer = 0.0
    refresh()

func refresh() -> void:
    if not is_instance_valid(world): return
    var sim = world.sim
    var next_signature := str(sim.world_origin) + str(sim.outpost_sites)
    for i in range(rows.size()):
        var row: Dictionary = rows[i]
        var site: Dictionary = Logistics.SITES[i]
        var discovered: bool = sim.explored.has(sim.cell_key(site.point))
        var post := Logistics.find(sim, i)
        row.title.text = site.name if discovered else "Unsurveyed %s site" % site.resource
        var blocked := Logistics.founding_block(sim, i)
        row.found.visible = post.is_empty()
        row.found.disabled = not blocked.is_empty()
        row.found.tooltip_text = blocked
        row.road.visible = not post.is_empty()
        row.route.visible = not post.is_empty()
        row.recall.visible = not post.is_empty()
        if post.is_empty():
            row.info.text = "Potential %s outpost. %s" % [site.resource, blocked]
        else:
            var cost := Logistics.road_cost(i)
            row.info.text = "%s · %d settlers + carrier\nFood %.1f · stored %s %.1f / 48\nRoute: %s · cargo %.1f · food shipment %.1f\nDelivered %.1f · reserve %s · road %.0f%%" % [post.stage, maxi(0, post.units.size() - 1), post.food, site.resource, post.stock, ("Paused / " if not post.enabled else "") + str(post.leg), post.cargo, post.shipment_food, post.delivered, ("renewable" if site.resource == "food" else "%.0f" % post.reserve), float(post.road) * 100]
            if post.leg in ["Inbound", "Outbound"]: row.info.text += "\nArrival in %.1f days" % ((1.0 - float(post.route_progress)) * Logistics.duration(sim, post))
            if post.food < 2: row.info.text += "\nLow provisions: production stops without food; crew recalls after 3 hungry days."
            if post.cargo > 0.001 and post.leg == "Home": row.info.text += "\nUnload waiting for town storage space."
            row.road.text = "Road %.0f%%" % (post.road * 100) if post.road_ordered else "Build road · %d wood / %d stone" % [cost.wood, cost.stone]
            row.road.disabled = post.road_ordered or post.stage in ["Recalling", "Returning"] or sim.resources.wood < cost.wood or sim.resources.stone < cost.stone
            row.road.tooltip_text = "Three settlers build this route. Finished roads double carrier capacity (8 → 16) and travel speed (1.5 → 3 map units/day)."
            row.route.text = "Resume supply route" if not post.enabled else "Pause supply route"
            row.route.disabled = post.stage in ["Recalling", "Returning"]
            row.recall.disabled = post.stage in ["Recalling", "Returning"]
            next_signature += "%d:%s:%d" % [i, post.stage, int(float(post.road) * 40)]
        next_signature += str(discovered)
    if signature != next_signature:
        signature = next_signature
        rebuild()

func rebuild() -> void:
    for child in geometry.get_children():
        geometry.remove_child(child)
        child.queue_free()
    var road_material := StandardMaterial3D.new()
    road_material.albedo_color = Color("9c8764")
    road_material.roughness = 1.0
    for i in range(Logistics.SITES.size()):
        var site: Dictionary = Logistics.SITES[i]
        if not world.sim.explored.has(world.sim.cell_key(site.point)): continue
        var post := Logistics.find(world.sim, i)
        var root := Node3D.new()
        geometry.add_child(root)
        root.position = world.pos(site.point.x, site.point.y, 0.08)
        var caption := Label3D.new()
        caption.text = site.name + ("\n" + str(post.stage) if not post.is_empty() else "\nResource site")
        caption.no_depth_test = true
        caption.font_size = 36
        caption.pixel_size = 0.018
        caption.position.y = 3.0
        caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        root.add_child(caption)
        if post.is_empty():
            post = world.sim.outpost_sites.get(str(i), {})
            if not post.is_empty(): draw_road(i, float(post.road), road_material)
            continue
        world.box(root, Vector3(0, 0.15, 0), Vector3(2.8, 0.3, 2.0), world.mats.wood)
        for x in [-1.2, 1.2]:
            for z in [-0.8, 0.8]:
                world.box(root, Vector3(x, 0.95, z), Vector3(0.12, 1.9, 0.12), world.mats.wood)
        world.box(root, Vector3(0, 1.9, 0), Vector3(3.2, 0.2, 2.4), world.mats.thatch)
        world.box(root, Vector3(0.7, 0.55, 0), Vector3(0.65, 0.7, 0.8), world.mats.wood)
        draw_road(i, float(post.road), road_material)

func draw_road(site_id: int, progress: float, material: Material) -> void:
    if progress <= 0: return
    var destination: Vector2 = Logistics.SITES[site_id].point
    var segments := ceili(Logistics.HOME.distance_to(destination) * 2)
    for j in range(ceili(segments * progress)):
        var a := Logistics.HOME.lerp(destination, float(j) / segments)
        var b := Logistics.HOME.lerp(destination, float(j + 1) / segments)
        world.beam(geometry, world.pos(a.x, a.y, 0.04), world.pos(b.x, b.y, 0.04), 0.30, material)
