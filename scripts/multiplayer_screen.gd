extends Control

var world: Node3D
var world_title: LineEdit
var nickname: LineEdit
var address: LineEdit
var port: SpinBox
var clock: OptionButton
var ai_counts: Dictionary = {}
var ai_help: Label
var resume_world: CheckBox
var status_label: Label
var players_label: Label
var result: Label
var host_button: Button
var join_button: Button
var leave_button: Button
var vote_button: Button
var enter_button: Button
var warfare_page: Control
var timer := 0.0
var trade_partner: OptionButton
var offered_resource: OptionButton
var wanted_resource: OptionButton
var offered_amount: SpinBox
var wanted_amount: SpinBox
var offers_list: ItemList
var visitor_list: ItemList
var scout_guard: OptionButton
var attack_visitors: Button
var visitor_signature := ""
var guard_signature := ""
var seize_offer: Button
var trade_result: Label
var relationship_label: Label
var send_offer: Button
var accept_offer: Button
var decline_offer: Button
var trade_signature := ""
var player_signature := ""
var pages: TabContainer
var sharing_row: VBoxContainer
var invite_address: LineEdit
var invite_text: LineEdit
var copy_invite: Button

func setup(scene: Node3D) -> void:
    world = scene
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var background := ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color("101b18")
    add_child(background)
    var panel := PanelContainer.new()
    panel.position = Vector2(240, 100)
    panel.size = Vector2(960, 700)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("192820")
    style.border_color = Color("968159")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(28)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    var column := VBoxContainer.new()
    var panel_column := column
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    var header := HBoxContainer.new()
    column.add_child(header)
    var title: Label = world.label("Create or join an ancient world", 28, Color("eee1bf"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    world.game_button(header, "Back to civilization · Esc", func(): hide())
    column.add_child(world.label("Up to %d civilizations · free player hosting · join at any time" % world.session.LIMIT, 15, Color("b7c9a9")))
    var tabs := TabContainer.new()
    pages = tabs
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(tabs)
    var world_scroll := ScrollContainer.new()
    world_scroll.name = "World"
    world_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(world_scroll)
    column = VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    world_scroll.add_child(column)
    make_trade_page(tabs)
    warfare_page = preload("res://scripts/warfare_screen.gd").new()
    tabs.add_child(warfare_page)
    warfare_page.setup(world)
    if "--warfare" in OS.get_cmdline_user_args(): tabs.current_tab = 2
    if "--barter" in OS.get_cmdline_user_args(): tabs.current_tab = 1
    column.add_child(HSeparator.new())
    world_title = LineEdit.new()
    world_title.placeholder_text = "Name your new world"
    world_title.text = "My world"
    world_title.max_length = 48
    column.add_child(world_title)
    var identity := HBoxContainer.new()
    column.add_child(identity)
    identity.add_child(world.label("Civilization name", 15, Color("ddd2b5")))
    nickname = LineEdit.new()
    nickname.text = "My civilization"
    nickname.max_length = 24
    nickname.custom_minimum_size.x = 240
    identity.add_child(nickname)
    identity.add_child(world.label("UDP port", 15, Color("ddd2b5")))
    port = SpinBox.new()
    port.min_value = 1024
    port.max_value = 65535
    port.value = 24567
    identity.add_child(port)
    var host_row := HBoxContainer.new()
    column.add_child(host_row)
    clock = OptionButton.new()
    clock.add_item("Saved clock / default")
    clock.add_item("1 real day / season")
    clock.add_item("1 real day / year")
    clock.add_item("Testing: day = 10 seconds")
    clock.add_item("Testing: day = 30 seconds")
    clock.tooltip_text = "Host chooses a shared speed, including when resuming. Testing worlds pause while the host is closed."
    host_row.add_child(clock)
    resume_world = CheckBox.new()
    resume_world.text = "Resume saved multiplayer world"
    resume_world.button_pressed = true
    host_row.add_child(resume_world)
    host_button = world.game_button(host_row, "Host world", func(): host_now())
    var ai_row := HBoxContainer.new()
    column.add_child(ai_row)
    ai_row.add_child(world.label("AI opponents", 15, Color("ddd2b5")))
    for level in ["Easy", "Normal", "Hard"]:
        ai_row.add_child(world.label("Medium" if level == "Normal" else level, 15, Color("ddd2b5")))
        var count := SpinBox.new()
        count.min_value = 0
        count.max_value = world.session.LIMIT - 1
        count.step = 1
        count.value = 0
        ai_counts[level] = count
        ai_row.add_child(count)
    ai_help = world.label("", 13, Color("9fb398"))
    ai_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(ai_help)
    resume_world.toggled.connect(func(_pressed): refresh())
    for count in ai_counts.values():
        count.value_changed.connect(func(_value): refresh())
    var join_row := HBoxContainer.new()
    column.add_child(join_row)
    address = LineEdit.new()
    address.placeholder_text = "Paste an invitation or enter the host address"
    address.custom_minimum_size.x = 520
    join_row.add_child(address)
    join_button = world.game_button(join_row, "Join world", func():
        result.text = world.session.join_game(nickname.text, address.text, int(port.value))
        refresh())
    world.game_button(join_row, "Paste", func(): address.text = DisplayServer.clipboard_get().strip_edges())
    sharing_row = VBoxContainer.new()
    sharing_row.add_theme_constant_override("separation", 8)
    column.add_child(sharing_row)
    sharing_row.add_child(world.label("Invite friends to this world", 18, Color("eee1bf")))
    var share_controls := HBoxContainer.new()
    sharing_row.add_child(share_controls)
    share_controls.add_child(world.label("Reachable host address", 14, Color("ddd2b5")))
    invite_address = LineEdit.new()
    invite_address.placeholder_text = "LAN IP, public IP, or hostname"
    invite_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    share_controls.add_child(invite_address)
    copy_invite = world.game_button(share_controls, "Copy invitation", func():
        var invitation: String = world.session.invitation(invite_address.text)
        if invitation.is_empty():
            result.text = "Enter a host IP address or hostname to share."
            return
        DisplayServer.clipboard_set(invitation)
        result.text = "Invitation copied. Send it to your friends; they paste it into Join world.")
    invite_text = LineEdit.new()
    invite_text.editable = false
    invite_text.tooltip_text = "Copy this invitation and send it to friends. Paste it into the game; it does not open a web page."
    sharing_row.add_child(invite_text)
    var share_help: Label = world.label("Same network: use the local IP below. Internet: enter your reachable public IP or hostname\nand forward this world's UDP port on your router. Keep the host game open.", 13, Color("9fb398"))
    share_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sharing_row.add_child(share_help)
    invite_address.text_changed.connect(func(_text): refresh_invitation())
    status_label = world.label("", 16, Color("d8bd7e"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel_column.add_child(status_label)
    column.add_child(HSeparator.new())
    players_label = world.label("", 16, Color("c5d3b8"))
    players_label.custom_minimum_size.y = 200
    column.add_child(players_label)
    var actions := HBoxContainer.new()
    column.add_child(actions)
    enter_button = world.game_button(actions, "Enter civilization", func(): hide())
    vote_button = world.game_button(actions, "Agree to advance up to one season", func(): result.text = world.session.vote_fast_forward())
    leave_button = world.game_button(actions, "Leave world", func(): world.session.leave(); refresh())
    result = world.label("", 14, Color("d9c59c"))
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel_column.add_child(result)
    var instructions: Label = world.label("Host: copy an invitation above and send it to friends. Join: paste it and choose Join world.\nFor a second window on this Mac, launch Multiplayer Guest.command and join 127.0.0.1.\nJoin at any time while a slot is free; no world restart needed.\nThe host must remain open for live play. Disconnected civilizations keep working.\nFast-forward needs every human owner's vote; AI opponents do not vote.\nDirect Internet play needs a reachable host/UDP port. Matchmaking is not available yet.", 13, Color("9fb398"))
    instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(instructions)
    visibility_changed.connect(func():
        if visible:
            move_to_front()
            world.dragging = false
            world.orbiting = false
            refresh())
    hide()
    refresh()

func selected_ai_counts() -> Dictionary:
    var counts: Dictionary = {}
    for level in ai_counts:
        counts[level] = int(ai_counts[level].value)
    return counts

func host_now() -> void:
    if not resume_world.button_pressed:
        world.session.world_name = world_title.text.strip_edges().left(48)
        if world.session.world_name.is_empty(): world.session.world_name = "My world"
    world.sim.save_game()
    result.text = world.session.host_game(nickname.text, int(port.value), [-1.0, 90.0, 360.0, 8640.0, 2880.0][clock.selected], resume_world.button_pressed, 0, "Normal", selected_ai_counts())
    refresh()
    if world.session.active:
        world.worlds_screen.selected = true
        world.worlds_screen.hide()
        invite_address.text = world.session.share_address
        refresh_invitation()
        world.feedback.text = "Shared world opened. Manage your civilization here; Multiplayer opens warfare, barter and world players."
        hide()

func open_barter(slot: int) -> void:
    refresh_trades()
    var index := trade_partner.get_item_index(slot)
    if index >= 0: trade_partner.select(index)
    pages.current_tab = 1
    show()

func open_warfare() -> void:
    warfare_page.pages.current_tab = 0
    pages.current_tab = 2
    show()

func refresh() -> void:
    var session = world.session
    var busy: bool = session.active or session.connecting
    host_button.disabled = busy
    join_button.disabled = busy
    leave_button.disabled = not busy
    vote_button.disabled = not session.active
    enter_button.disabled = not session.active
    nickname.editable = not busy
    address.editable = not busy
    port.editable = not busy
    clock.disabled = busy
    resume_world.disabled = busy
    world_title.editable = not busy and not resume_world.button_pressed
    sharing_row.visible = session.active and world.multiplayer.is_server()
    refresh_invitation()
    var resuming := resume_world.button_pressed and FileAccess.file_exists(session.world_save_path)
    var ai_total := 0
    for count in ai_counts.values():
        count.editable = not busy and not resuming
        ai_total += int(count.value)
    if not busy and not resuming:
        host_button.disabled = ai_total >= session.LIMIT
    ai_help.text = "Resuming keeps each saved AI opponent and its difficulty. Uncheck Resume to choose a new mix." if resuming else "%d AI opponents · %d slots left for friends (host uses one). Maximum %d AI total.\nEasy: slower, cautious. Medium: balanced. Hard: faster decisions and stronger raids." % [ai_total, maxi(0, session.LIMIT - 1 - ai_total), session.LIMIT - 1]
    status_label.text = session.status
    if session.active:
        var speed_text: String = "Testing · 1 day / %d seconds" % int(86400.0 / session.clock_days) if session.clock_days > 360 else "1 real day / %s" % ("year" if session.clock_days == 360 else "season")
        status_label.text += "\nShared clock: " + speed_text
    refresh_trades()
    var lines := PackedStringArray()
    for player in session.roster:
        if player.get("ai", false):
            lines.append("%s · AI · %s" % [player.name, "Medium" if player.get("difficulty", "Normal") == "Normal" else player.get("difficulty", "Normal")])
            continue
        lines.append("%s · %s · %s" % [player.name, "connected" if player.online else "offline · essential work continues", "agreed to advance" if player.voted else "not voted"])
    players_label.text = "WORLD CIVILIZATIONS · %d / %d slots\n" % [session.roster.size(), session.LIMIT] + ("\n".join(lines) if not lines.is_empty() else "Host a fresh world or resume it. Joining creates your civilization or restores your saved one.\nChoose zero AI opponents to leave all other slots for real people.")

func refresh_invitation() -> void:
    if world.session.active and world.multiplayer.is_server() and not invite_address.text.strip_edges().is_empty():
        world.session.share_address = invite_address.text.strip_edges()
    invite_text.text = world.session.invitation(invite_address.text)
    copy_invite.disabled = invite_text.text.is_empty()

func _process(delta: float) -> void:
    if not visible: return
    timer += delta
    if timer >= 0.5:
        timer = 0
        refresh()

func resource_selector(row: HBoxContainer) -> OptionButton:
    var selector := OptionButton.new()
    for resource in ["food", "wood", "stone"]: selector.add_item(resource.capitalize())
    row.add_child(selector)
    return selector

func amount_selector(row: HBoxContainer) -> SpinBox:
    var amount := SpinBox.new()
    amount.min_value = 1
    amount.max_value = 10000
    amount.value = 10
    amount.custom_minimum_size.x = 100
    row.add_child(amount)
    return amount

func make_trade_page(tabs: TabContainer) -> void:
    var scroll := ScrollContainer.new()
    scroll.name = "Barter"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.add_child(scroll)
    var page := VBoxContainer.new()
    page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page.add_theme_constant_override("separation", 16)
    scroll.add_child(page)
    page.add_child(world.label("Trade with another civilization", 23, Color("eee1bf")))
    page.add_child(world.label("Offer materials in exchange for what you need. Both players must agree.", 15, Color("b7c9a9")))
    var partner_row := HBoxContainer.new()
    page.add_child(partner_row)
    partner_row.add_child(world.label("Trade partner", 15, Color("ddd2b5")))
    trade_partner = OptionButton.new()
    trade_partner.custom_minimum_size.x = 280
    partner_row.add_child(trade_partner)
    relationship_label = world.label("", 14, Color("d9c59c"))
    relationship_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(relationship_label)
    var give_row := HBoxContainer.new()
    page.add_child(give_row)
    give_row.add_child(world.label("You offer", 16, Color("ddd2b5")))
    offered_resource = resource_selector(give_row)
    offered_amount = amount_selector(give_row)
    give_row.add_child(world.label("You request", 16, Color("ddd2b5")))
    wanted_resource = resource_selector(give_row)
    wanted_resource.select(1)
    wanted_amount = amount_selector(give_row)
    send_offer = world.game_button(give_row, "Send offer", func():
        trade_result.text = world.order("offer_trade", [trade_partner.get_selected_id(), ["food", "wood", "stone"][offered_resource.selected], int(offered_amount.value), ["food", "wood", "stone"][wanted_resource.selected], int(wanted_amount.value)]))
    page.add_child(HSeparator.new())
    page.add_child(world.label("Visiting scouts · defend your civilization", 18, Color("eee1bf")))
    visitor_list = ItemList.new()
    visitor_list.custom_minimum_size.y = 95
    page.add_child(visitor_list)
    scout_guard = OptionButton.new()
    page.add_child(scout_guard)
    attack_visitors = world.game_button(page, "Use selected army to kill visiting scouts", func():
        var chosen := visitor_list.get_selected_items()
        if chosen.is_empty(): return
        var party: Dictionary = visitor_list.get_item_metadata(chosen[0])
        trade_result.text = world.order("attack_scouts", [int(party.slot), float(party.started), party.units, scout_guard.get_selected_id()]))
    attack_visitors.tooltip_text = "Ready armies at home can kill ordinary or trade scouts inside home influence. Relations deteriorate; cargo is seized within town storage."
    page.add_child(HSeparator.new())
    offers_list = ItemList.new()
    offers_list.custom_minimum_size.y = 220
    offers_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page.add_child(offers_list)
    var actions := HBoxContainer.new()
    page.add_child(actions)
    accept_offer = world.game_button(actions, "Accept selected offer", func(): trade_action("accept_trade"))
    decline_offer = world.game_button(actions, "Decline / cancel selected offer", func(): trade_action("decline_trade"))
    seize_offer = world.game_button(actions, "Kill scouts / seize cargo", func(): trade_action("seize_trade"))
    seize_offer.tooltip_text = "Uses a ready army at home to kill the three visiting settlers and takes cargo within storage capacity. Severely damages relations."
    trade_result = world.label("Offers travel with three settlers and reserved cargo. Decide when visiting scouts arrive.", 14, Color("d9c59c"))
    trade_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(trade_result)
    page.add_child(world.label("Acceptance checks both stockpiles and storage capacity.
Scouts carry offers out and payment home. Declined offers return with their cargo. Killing visiting scouts damages relations.", 13, Color("9fb398")))

func trade_action(action: String) -> void:
    var selected_items := offers_list.get_selected_items()
    if selected_items.is_empty():
        trade_result.text = "Select a pending offer first."
        return
    trade_result.text = world.order(action, [int(offers_list.get_item_metadata(selected_items[0]))])

func refresh_trades() -> void:
    var session = world.session
    var visitors: Array = session.cached_own.get("visiting_scouts", []) if session.active else []
    if visitor_signature != str(visitors):
        var previous: Dictionary = {}
        if not visitor_list.get_selected_items().is_empty(): previous = visitor_list.get_item_metadata(visitor_list.get_selected_items()[0])
        visitor_signature = str(visitors)
        visitor_list.clear()
        for party in visitors:
            var index := visitor_list.add_item("%s · %d %s scouts" % [party.name, party.units.size(), "trade" if party.trade else "exploration"])
            visitor_list.set_item_metadata(index, party)
            if party == previous: visitor_list.select(index)
    var guards: Array = []
    for army in world.sim.armies:
        if army.status == "Ready" and not army.get("reserve", false) and not army.soldiers.is_empty(): guards.append({"id": army.id, "name": army.name})
    if guard_signature != str(guards):
        guard_signature = str(guards)
        var previous_id := scout_guard.get_selected_id()
        scout_guard.clear()
        for army in guards: scout_guard.add_item(army.name, int(army.id))
        var previous_index := scout_guard.get_item_index(previous_id)
        if previous_index >= 0: scout_guard.select(previous_index)
    attack_visitors.disabled = not session.active or guards.is_empty() or visitor_list.get_selected_items().is_empty()
    var own_slot := int(session.cached_own.get("slot", -1))
    var signature := str(session.roster) + str(own_slot) + str(world.sim.known_civilizations.keys())
    if player_signature != signature:
        player_signature = signature
        var selected_id := trade_partner.get_selected_id()
        trade_partner.clear()
        for player in session.roster:
            if player.slot != own_slot and world.sim.known_civilizations.has(str(int(player.slot))): trade_partner.add_item(player.name, player.slot)
        var previous := trade_partner.get_item_index(selected_id)
        if previous >= 0: trade_partner.select(previous)
    var relations: Dictionary = session.cached_own.get("relationships", {})
    var relation: Dictionary = relations.get(str(trade_partner.get_selected_id()), {})
    relationship_label.text = "Relationship: %s (%d).\nResource needs and relations influence decisions. Accepted trades improve relations; killing scouts damages them." % [relation.status, int(relation.score)] if not relation.is_empty() else ("Human civilization · the player decides whether to accept." if trade_partner.item_count > 0 else "Discover an AI civilization to see its relationship with you.")
    var next_trades := str(session.visible_trades)
    if trade_signature != next_trades:
        trade_signature = next_trades
        var selected_id := -1
        var selected_items := offers_list.get_selected_items()
        if not selected_items.is_empty(): selected_id = int(offers_list.get_item_metadata(selected_items[0]))
        offers_list.clear()
        for offer in session.visible_trades:
            var text := "%s · %s · %s → %s: %d %s for %d %s" % [offer.get("stage", "Awaiting decision"), "RECEIVED" if offer.incoming else "SENT", offer.from_name, offer.to_name, offer.give_amount, offer.give, offer.ask_amount, offer.ask]
            var index := offers_list.add_item(text)
            offers_list.set_item_metadata(index, offer.id)
            if offer.id == selected_id: offers_list.select(index)
    send_offer.disabled = not session.active or trade_partner.item_count == 0
    accept_offer.disabled = not session.active or offers_list.get_selected_items().is_empty()
    decline_offer.disabled = accept_offer.disabled
    seize_offer.disabled = true
    accept_offer.disabled = true
    var selected := offers_list.get_selected_items()
    if not selected.is_empty():
        var offer_id := int(offers_list.get_item_metadata(selected[0]))
        for offer in session.visible_trades:
            if int(offer.id) == offer_id:
                var arrived: bool = offer.incoming and offer.get("stage", "") == "Awaiting decision"
                accept_offer.disabled = not session.active or not arrived
                seize_offer.disabled = accept_offer.disabled or guards.is_empty()
                decline_offer.disabled = not session.active or (offer.incoming and not arrived)
