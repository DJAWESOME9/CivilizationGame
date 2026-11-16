extends SceneTree

func _initialize() -> void:
    run.call_deferred()

func run() -> void:
    var world = load("res://main.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await process_frame
    world.worlds_screen.hide()
    world.sim.save_path = ""
    world.sim.technologies = world.sim.TECHNOLOGIES.keys()
    world.sim.resources = {"food": 100.0, "wood": 70.0, "stone": 50.0}
    world.sim.reveal_land(Vector2(-4, 0), 65)
    world.order("found_outpost", [0])
    for i in range(160):
        world.sim.day += 0.25
        world.sim.Outposts.advance(world.sim, 0.25)
    world.order("outpost_road", [0])
    for i in range(100):
        world.sim.day += 0.25
        world.sim.Outposts.advance(world.sim, 0.25)
    world.sim.prepare_roster(world.sim.assignments)
    world.citizens.sync_people()
    world.refresh_game()
    var page = world.exploration_label.get_parent()
    var scroll = page.get_parent()
    var tabs = scroll.get_parent()
    while not tabs is TabContainer: tabs = tabs.get_parent()
    for i in range(tabs.get_tab_count()):
        if tabs.get_tab_title(i) == "Explore": tabs.current_tab = i
    world.camera_size = 62
    world.focus = Vector3(-12, 0, -5)
    world.update_camera()
    for i in range(8): await process_frame
    scroll.scroll_vertical = 240
    world.outposts_view.refresh()
    await process_frame
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("/tmp/civilization-outposts-preview.png")
    print("Native outpost scene rendered: ", world.sim.outposts[0].stage, ", road ", world.sim.outposts[0].road)
    quit()
